function labels = get_AAL3_labels(exclude_indices)
% get_AAL3_labels
% Returns ROI labels for AAL3v1 atlas
%
% INPUT:
%   exclude_indices - Vector of ROI indices to exclude (e.g., [35, 36, 81, 82])
%                     Optional, default: []
%
% OUTPUT:
%   labels - Cell array of ROI short names

if nargin < 1
    exclude_indices = [];
end

% Full AAL3v1 labels (170 ROIs)
all_labels = {
    'PreCG_L', 'PreCG_R', ...              % 1-2
    'SFG_L', 'SFG_R', ...                  % 3-4
    'MFG_L', 'MFG_R', ...                  % 5-6
    'IFGoperc_L', 'IFGoperc_R', ...        % 7-8
    'IFGtriang_L', 'IFGtriang_R', ...      % 9-10
    'IFGorb_L', 'IFGorb_R', ...            % 11-12
    'ROL_L', 'ROL_R', ...                  % 13-14
    'SMA_L', 'SMA_R', ...                  % 15-16
    'OLF_L', 'OLF_R', ...                  % 17-18
    'SFGmedial_L', 'SFGmedial_R', ...      % 19-20
    'PFCventmed_L', 'PFCventmed_R', ...    % 21-22
    'REC_L', 'REC_R', ...                  % 23-24
    'OFCmed_L', 'OFCmed_R', ...            % 25-26
    'OFCant_L', 'OFCant_R', ...            % 27-28
    'OFCpost_L', 'OFCpost_R', ...          % 29-30
    'OFClat_L', 'OFClat_R', ...            % 31-32
    'INS_L', 'INS_R', ...                  % 33-34
    'ACC_L', 'ACC_R', ...                  % 35-36 (exclude)
    'MCC_L', 'MCC_R', ...                  % 37-38
    'PCC_L', 'PCC_R', ...                  % 39-40
    'HIP_L', 'HIP_R', ...                  % 41-42
    'PHG_L', 'PHG_R', ...                  % 43-44
    'AMYG_L', 'AMYG_R', ...                % 45-46
    'CAL_L', 'CAL_R', ...                  % 47-48
    'CUN_L', 'CUN_R', ...                  % 49-50
    'LING_L', 'LING_R', ...                % 51-52
    'SOG_L', 'SOG_R', ...                  % 53-54
    'MOG_L', 'MOG_R', ...                  % 55-56
    'IOG_L', 'IOG_R', ...                  % 57-58
    'FFG_L', 'FFG_R', ...                  % 59-60
    'PoCG_L', 'PoCG_R', ...                % 61-62
    'SPG_L', 'SPG_R', ...                  % 63-64
    'IPG_L', 'IPG_R', ...                  % 65-66
    'SMG_L', 'SMG_R', ...                  % 67-68
    'ANG_L', 'ANG_R', ...                  % 69-70
    'PCUN_L', 'PCUN_R', ...                % 71-72
    'PCL_L', 'PCL_R', ...                  % 73-74
    'CAU_L', 'CAU_R', ...                  % 75-76
    'PUT_L', 'PUT_R', ...                  % 77-78
    'PAL_L', 'PAL_R', ...                  % 79-80
    'THA_L', 'THA_R', ...                  % 81-82 (exclude)
    'HES_L', 'HES_R', ...                  % 83-84
    'STG_L', 'STG_R', ...                  % 85-86
    'TPOsup_L', 'TPOsup_R', ...            % 87-88
    'MTG_L', 'MTG_R', ...                  % 89-90
    'TPOmid_L', 'TPOmid_R', ...            % 91-92
    'ITG_L', 'ITG_R', ...                  % 93-94
    'CERCRU1_L', 'CERCRU1_R', ...          % 95-96
    'CERCRU2_L', 'CERCRU2_R', ...          % 97-98
    'CER3_L', 'CER3_R', ...                % 99-100
    'CER4_5_L', 'CER4_5_R', ...            % 101-102
    'CER6_L', 'CER6_R', ...                % 103-104
    'CER7b_L', 'CER7b_R', ...              % 105-106
    'CER8_L', 'CER8_R', ...                % 107-108
    'CER9_L', 'CER9_R', ...                % 109-110
    'CER10_L', 'CER10_R', ...              % 111-112
    'VER1_2', ...                          % 113
    'VER3', ...                            % 114
    'VER4_5', ...                          % 115
    'VER6', ...                            % 116
    'VER7', ...                            % 117
    'VER8', ...                            % 118
    'VER9', ...                            % 119
    'VER10', ...                           % 120
    'tAV_L', 'tAV_R', ...                  % 121-122
    'tLP_L', 'tLP_R', ...                  % 123-124
    'tVA_L', 'tVA_R', ...                  % 125-126
    'tVL_L', 'tVL_R', ...                  % 127-128
    'tVPL_L', 'tVPL_R', ...                % 129-130
    'tIL_L', 'tIL_R', ...                  % 131-132
    'tRe_L', 'tRe_R', ...                  % 133-134
    'tMDm_L', 'tMDm_R', ...                % 135-136
    'tMDl_L', 'tMDl_R', ...                % 137-138
    'tLGN_L', 'tLGN_R', ...                % 139-140
    'tMGN_L', 'tMGN_R', ...                % 141-142
    'tPuA_L', 'tPuA_R', ...                % 143-144
    'tPuM_L', 'tPuM_R', ...                % 145-146
    'tPuL_L', 'tPuL_R', ...                % 147-148
    'tPuI_L', 'tPuI_R', ...                % 149-150
    'ACCsub_L', 'ACCsub_R', ...            % 151-152
    'ACCpre_L', 'ACCpre_R', ...            % 153-154
    'ACCsup_L', 'ACCsup_R', ...            % 155-156
    'Nacc_L', 'Nacc_R', ...                % 157-158
    'VTA_L', 'VTA_R', ...                  % 159-160
    'SNpc_L', 'SNpc_R', ...                % 161-162
    'SNpr_L', 'SNpr_R', ...                % 163-164
    'RedN_L', 'RedN_R', ...                % 165-166
    'LC_L', 'LC_R', ...                    % 167-168
    'RapheD', ...                          % 169
    'RapheM' ...                           % 170
};

% Remove excluded indices
if ~isempty(exclude_indices)
    all_labels(exclude_indices) = [];
end

labels = all_labels;

end
