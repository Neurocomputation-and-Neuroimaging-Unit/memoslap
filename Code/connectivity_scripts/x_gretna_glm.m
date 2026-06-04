
function [stat] = gretna_glm(respmatrix, desnmatrix, type,k);

% respmatrix: n*m: n is the number of subjects (or time points); m is the number of vertices
% desmatrix: n*m: n is the number of subjects (or time pointes); m is the number of
% covariates.
% type:
%  if type = 't'; k: the kth statistical value, e.g. k=1;
%  if type = 'r' (i.e. residual);
% Yong HE, BIC,MNI. 2007/06
%
% example:
% 1. [stat] = gretna_glm(respmatrix, [age], 't',1);
% 2. [stat] = gretna_glm(respmatrix, [age gender clinic], 't',3);
% 3. [stat] = gretna_glm(respmatrix, [age gender], 'r');
%

n = size(respmatrix,1);
m = size(respmatrix,2);

if type == 't'
    for i = 1:m
        resp = respmatrix(:,i);
        s = regstats(resp,desnmatrix,'linear',{'tstat'});
        stat.t(i,1) = s.tstat.t(k+1);
        stat.p(i,1) = s.tstat.pval(k+1);
        stat.beta(i,1) = s.tstat.beta(k+1);
    end
    stat.df = s.tstat.dfe;
end

if type == 'r'
    for i = 1:m

        resp = respmatrix(:,i);
        s = regstats(resp,desnmatrix,'linear',{'r'});
        stat.r(:,i) = s.r;
    end
end