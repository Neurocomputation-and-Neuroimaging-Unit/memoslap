%% Compute Pair-correlation between two sample matrices.
function R = x_calcPairCorr(X, Y)
%
% XiNian.Zuo@nyumc.org

[numCorr1, numSamp1] = size(X);
[numCorr2, numSamp2] = size(Y);

if (numCorr1 ~= numCorr2) || (numSamp1 ~= numSamp2)
    disp('The two matices must have the same size!')
else
    X = (X - repmat(mean(X, 2), 1, numSamp1))./repmat(std(X, 0, 2), 1, numSamp1);
    Y = (Y - repmat(mean(Y, 2), 1, numSamp1))./repmat(std(Y, 0, 2), 1, numSamp1);
    R = dot(X,Y,2) / (numSamp1 - 1);
end