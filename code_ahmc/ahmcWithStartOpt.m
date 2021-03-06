function [out] = ahmcWithStartOpt(NumOfIterations, BurnIn, bounds, gradient, func, D, q0)
% Adaptive HMC using Bayesian optimization.

% Input Arguments:
% - NumOfIterations:    Total number of iterations.
% - BurnIn:             The number of samples used for burn in. Note, this
%                       number determines the number of adaptation steps.
% - func:               A function handle that returns the NEGATIVE log density.
% - gradient:           A function handle that returns the NEGATIVE log gradient
%                       of the target density
% - D:                  Dimensionality of the state space.
% - q0:                 Start value for ahmc.

% Outputs:
% - out:                Samples as well as other information generated by the 
%                       sampler.

% Authors: Ziyu Wang, Shakir Mohamed (2013)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Adaptive setup
adapt = 1;
size_adapt = floor(BurnIn/100);
adjust_reward = 1;

% Annealing schedule
prob = @(x)max((x- BurnIn - 1)/size_adapt+1, 1)^(-0.5);

% BO setup
bounds(1,:) = log(bounds(1,:));
pt = bounds(:,1); pt(2) = ceil(pt(2));
hyp = [0.2*(bounds(1,2)-bounds(1,1)); 0.2*(bounds(2,2)-bounds(2,1)); 5];
hyp = log(hyp);

% DIRECT options.
dopt.maxevals = 200; dopt.maxits = 50; dopt.showits = 0;

%% For book keeping.
num_adapt = 0; total_RandomStep = 0; num_steps = 0;
reward = 0; out.epsilon = []; out.leapFrogs = []; out.reward = [];
out.energy = []; out.saved = zeros(NumOfIterations-BurnIn,D);
total_num_accepted = 0;

%% Initialize to a mode. NEW: Optimize with the given starting value
options.display = 'none';
options.maxFunEvals = ceil(bounds(2,2)*2);
[q, f] = minFunc(@objective, q0(:), options);

%% Begin Sampling
for IterationNum = 1:(NumOfIterations)   
    if adapt
        if IterationNum == 1
            NumOfLeapFrogSteps = round(pt(2));
            StepSize = exp(pt(1));            
        elseif mod(IterationNum, size_adapt) == 1
            if adjust_reward; reward = reward/sqrt(NumOfLeapFrogSteps); end;
            
            num_adapt = num_adapt + 1;

            if IterationNum == size_adapt + 1
                model = init_model(2, bounds, pt', reward, hyp, 0.1, 'ard');
            else
                model = update_model(model, reward, pt', 0);
            end
            
            anneal = IterationNum;
    
            fprintf('\rIter: %3d; Epsilon: [%f]; L: %4d; Reward %f; prob: %.3f', ...
                num_adapt, StepSize, NumOfLeapFrogSteps, reward, prob(anneal));
            
            if rand < prob(anneal)
                pt = maximize_acq(model, dopt, 'ucb', prob(anneal));
                NumOfLeapFrogSteps = round(pt(2)); StepSize = exp(pt(1));
            end
            reward = 0;
        end

        out.epsilon(end+1) = StepSize;
        out.leapFrogs(end+1) = NumOfLeapFrogSteps; out.reward(end+1) = reward;
    end

    %% Do HMC iteration.
    q_old = q;
    [q, accept, q_prop, mr, RandomStep, energy] = ...
        hmc_iter(NumOfLeapFrogSteps, StepSize, q_old, gradient, func);
    
    %% Update rewards.
    % Note: Some modifications made by Wolfgang Roth to avoid '0 * inf = nan' computations
    reward_update = mr*norm(q_old-q_prop).^2;
    if ~isnan(reward_update)
      reward = reward + reward_update;
    end
    %reward = reward + mr*norm(q_old-q_prop).^2;

    %% Save Energy.
    out.energy(end+1) = energy;

    %% Save samples if required.
    if IterationNum > BurnIn
        total_num_accepted = total_num_accepted + accept;
        num_steps = num_steps + 1;
        total_RandomStep = total_RandomStep + RandomStep;    
        out.saved(IterationNum-BurnIn,:) = q;
    end
end

out.total_RandomStep = total_RandomStep;
out.total_num_accepted = total_num_accepted;

fprintf('\n');

function [f, g] = objective(x)
    f = func(x); g = gradient(x);
end

end
