function grad = funDpnnErrorGradient(w, model, x, t)
% Wrapper that can be used for functions that expect a function handle of
% the gradient of the error function of DP neural networks using vectorized
% weights.
%
% Input:
% w: The vectorized weights of the DP neural network.
% model: The DP neural network template. The weights of the model are
%   replaced by w.
% x: The input vectors stored in a matrix where rows correspond to
%   different samples and columns correspond to different features.
% t: The output vectors stored in a matrix where rows correspond to
%   different samples. In case the task of the model is 'regress' or
%   'biclass', the columns correspond to different outputs. In case the
%   task of the model is 'muclass', t must be a column vector containing
%   the class labels as integers starting from 1.
%
% Output:
% grad: The vectorized gradient of the error function with respect to the
%   weights (see dpnnErrorGradient)
%
% Example:
% grad = @(w) funDpnnErrorGradient(w, model, x, t);
%
% @author Wolfgang Roth

w_size = size(w);
w = w(:)';

if strcmp(model.sharing, 'layerwise')
  start_idx = 1;
  for l = 1:model.num_layers
    end_idx = start_idx + model.num_unique_weights(l) - 1;
    model.W{l} = w(start_idx:end_idx);
    start_idx = end_idx + 1;
  end
elseif strcmp(model.sharing, 'global')
  model.W = w;
else
  error('Error in ''funDpnnErrorGradient'': Unrecognized sharing ''%s''', model.sharing);
end

grad = dpnnErrorGradient(model, x, t);

if strcmp(model.sharing, 'layerwise')
  grad = cat(2, grad{:});
end

grad = reshape(grad, w_size);

end