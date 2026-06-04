function B11_regress_out_nuisance_new(run_dir, run_name, currPrefix)
% -------------------------------------------------------------------------
% Step 11: Joint nuisance regression
% Regresses out:
%   - motion parameters
%   - CompCor components
%   - global signal
%   - linear trend
%   - quadratic trend
% using a GM mask
% -------------------------------------------------------------------------

fprintf('    Regressing nuisance signals...\n');

%% ------------------------------------------------------------------------
f = spm_select('List', run_dir, ['^' currPrefix run_name]);
rest_file = fullfile(run_dir, strtrim(f));

[data, header] = rp_ReadNiftiImage(rest_file);
[nDim1, nDim2, nDim3, nDimTimePoints] = size(data);

Y = reshape(data, [], nDimTimePoints)';   % time x voxels


% Load motion parameters
rp_file = spm_select('List', run_dir, ['^rp_.*' run_name(1:end-4) '.*\.txt$']);
motion = load(fullfile(run_dir, rp_file));

% Load CompCor regressors
cc_file = spm_select('List', run_dir, ['.*' run_name(1:end-4) '.*_CompCorPCs\.mat$']);
cc = load(fullfile(run_dir, cc_file));
compcorr = cc.PCs;


% Load GS and trends from Step 10
nuisance_file = fullfile(run_dir, ['nuisance_' currPrefix run_name(1:end-4) '.mat']);
load(nuisance_file, 'GS', 'trends');

% Assemble nuisance design matrix
X = [motion, compcorr, GS(:), trends];

% Normalize regressors jointly (like original logic)
X = detrend(X, 'constant');
X = X ./ std(X);

% Regress nuisance signals (unchanged math)
beta = (X' * X) \ (X' * Y);
Y_clean = Y - X * beta;

% reshape back to 4D
data_clean = reshape(Y_clean', nDim1, nDim2, nDim3, nDimTimePoints);


% Write output
header.fname = fullfile(run_dir, ['n' currPrefix run_name]);
rp_Write4DNIfTI(data_clean, header, header.fname);

fprintf('Nuisance regression complete: %s\n', header.fname);

end