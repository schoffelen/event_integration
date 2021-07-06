function rt_collectsourcedata(varargin)

% Function that calculates statistics based on connectivity data

saveflag        = ft_getopt(varargin, 'saveflag', false);
savepath        = ft_getopt(varargin, 'savepath', '/project/3012026.13/jansch/');
datadir         = ft_getopt(varargin, 'datadir', '/project/3012026.13/jansch/');
savename        = ft_getopt(varargin, 'savename', 'coherence'); 
suff            = ft_getopt(varargin, 'suff', '_coh.mat');
connectivity    = ft_getopt(varargin, 'connectivity', 'coh');
atlasgrid       = ft_getopt(varargin, 'headdata', fullfile('/project/3012026.13/jansch/', 'brainnetome_atlas_grid.mat'));
atlasrois       = ft_getopt(varargin, 'atlasrois', 'all'); % Either all or cell array with ROIs
method          = ft_getopt(varargin, 'method', 'avg'); % can also be 'stat'

cd(datadir);
load(atlasgrid)

cfg1 = [];
cfg1.appenddim = 'rpt';

cfg2 = [];
cfg2.avgoverrpt = 'yes';

d = dir(sprintf('sub*%s*',suff));
for k = 1:numel(d)
  
  disp(strcat('Subject aggregation:', int2str(k)))
    
  data_all = load(d(k).name);
  switch connectivity
      case 'coh'
          data = data_all.coh;
          fname = 'cohspctrm';
      case 'imcoh'
          data = data_all.imcoh;
          fname = 'cohspctrm';
      case 'mim'
          data = data_all.mim;
          fname = 'cohspctrm';
  end
  conlabel = data_all.conlabel;
  clear data_all
  
  istimelock = ft_datatype(data{1}, 'timelock');
  isfreq     = ft_datatype(data{1}, 'freq');
  
  % Loop trough each condition
  for m = 1:numel(data)
    F{m,k} = data{m}; % Results in: F = 6 X 32 Structure (cond x subs)
  end
  clear data
end

if istimelock
    switch method
        case 'avg'
          for m = 1:size(F,1)
            Fcon{m} = ft_selectdata(cfg2, ft_appendtimelock(cfg1, F{:,m})); % I think I need to switch the : with the m to avg over subs instead of cond
          end
        case 'stat'
            % Do statistics
    end
elseif isfreq
    switch method
        case 'avg'
            for m = 1:size(F,1) 
                Fcon{m} = ft_selectdata(cfg2, ft_appendfreq(cfg1, F{:,m}));
            end
        case 'stat'
            sorted_idx = get_sortedrois(F{1,1}.label, atlasrois);
            Fcon = dostatsMC(F, sorted_idx, fname);
    end
end

clear F

subj = {d.name}';
for k = 1:numel(subj)
  subj{k} = subj{k}(1:7);
end


%% Save variables

if saveflag
    fname = fullfile(savepath, sprintf('%s_%s_%s', 'groupdata', connectivity, savename));
    save(fname, 'Fcon', 'subj', 'conlabel', 'connectivity');
end



%% -------------------------- SUB FUNCTIONS -------------------------- %%

function [sorted_idx] = get_sortedrois(datalabels, atlasrois)

% Sorts the ROIs or all parcels to left and right hemisphere
% Provides index for further analyses

idx         = [];
leftidx     = [];
rightidx    = [];
if strcmp(atlasrois, 'all')
    atlasrois = datalabels;
end
for lab = 1:numel(datalabels)
    for roirun = 1:numel(atlasrois)
        if contains(datalabels{lab}, atlasrois(roirun))
            idx = [idx; lab];
            if contains(datalabels{lab}, 'Left')
                leftidx = [leftidx; true];
                rightidx = [rightidx; false];
            elseif contains(datalabels{lab}, 'Right')
                leftidx = [leftidx; false];
                rightidx = [rightidx; true];
            end
        end
    end
end
left_side   = idx(logical(leftidx));
right_side  = idx(logical(rightidx));
sorted_idx  = [left_side; flip(right_side)];


function [stat] = dostatsMC(Fdata, roiselection, fname)

% Subfunction to perform statistical calculations

orgsize = size(Fdata{1,1}.(fname)(roiselection, roiselection));
for i = 1:size(Fdata, 1)
    for j = 1:size(Fdata, 2)
        % Select data from ROIs
        Fdata{i, j}.(fname) = Fdata{i, j}.(fname)(roiselection, roiselection);
        % Select lower triangle
        trilsel = tril(Fdata{i, j}.(fname), -1);
        % Replace datafield with new data vector
        Fdata{i, j}.(fname) = Fdata{i, j}.(fname)(trilsel>0);
    end
end
% Do stats on specific contrasts
nsubj       = size(Fdata, 2);
cfg         = [];
cfg.design  = [ones(1,nsubj) ones(1,nsubj)*2; 1:nsubj 1:nsubj];
cfg.ivar    = 1;
cfg.uvar    = 2;
cfg.alpha           = 0.05;
cfg.correcttail     = 'alpha';
cfg.tail            = 0;
cfg.correctm        = 'bonferroni';
cfg.statistic       = 'depsamplesT';
cfg.method          = 'montecarlo';
cfg.parameter       = fname;
cfg.numrandomization    = 1000;
% A(post) - A(pre)
stat{1,1}   = ft_freqstatistics(cfg, Fdata{4,:}, Fdata{1,:});
stat{1,1}.orgdim = orgsize;
% B(post) - B(pre)
stat{2,1}   = ft_freqstatistics(cfg, Fdata{5,:}, Fdata{2,:});
stat{2,1}.orgdim = orgsize;
% X(post) - X(pre)
stat{3,1}   = ft_freqstatistics(cfg, Fdata{6,:}, Fdata{3,:});
stat{3,1}.orgdim = orgsize;

 
% function [stat] = dostats(Fdata, roiselection, fname)
% 
% % Subfunction to perform statistical calculations
% 
% orgsize = size(Fdata{1,1}.(fname)(roiselection, roiselection));
% for i = 1:size(Fdata, 1)
%     for j = 1:size(Fdata, 2)
%         % Select data from ROIs
%         Fdata{i, j}.(fname) = Fdata{i, j}.(fname)(roiselection, roiselection);
%         % Select lower triangle
%         trilsel = tril(Fdata{i, j}.(fname), -1);
%         % Replace datafield with new data vector
%         Fdata{i, j}.(fname) = Fdata{i, j}.(fname)(trilsel>0);
%     end
% end
% % Do stats on specific contrasts
% nsubj       = size(Fdata, 2);
% cfg         = [];
% design      = [ones(1,nsubj) ones(1,nsubj)*2; 1:nsubj 1:nsubj];
% cfg.ivar    = 1;
% cfg.uvar    = 2;
% cfg.computecritval  = 'yes';
% cfg.computeprob     = 'yes';
% cfg.alpha           = 0.05;
% cfg.tail            = 0;
% % A(post) - A(pre)
% for i = 1:size(Fdata, 2)
%     datapost(:,i) = Fdata{4,i}.(fname);
%     datapre(:,i)  = Fdata{1,i}.(fname);
% end
% stat{1,1}   = ft_statfun_depsamplesT(cfg, [datapost datapre], design);
% stat{1,1}.orgdim = orgsize;
% % B(post) - B(pre)
% for i = 1:size(Fdata, 2)
%     datapost(:,i) = Fdata{5,i}.(fname);
%     datapre(:,i)  = Fdata{2,i}.(fname);
% end
% stat{2,1}   = ft_statfun_depsamplesT(cfg, [datapost datapre], design);
% stat{2,1}.orgdim = orgsize;
% % X(post) - X(pre)
% for i = 1:size(Fdata, 2)
%     datapost(:,i) = Fdata{6,i}.(fname);
%     datapre(:,i)  = Fdata{3,i}.(fname);
% end
% stat{3,1}   = ft_statfun_depsamplesT(cfg, [datapost datapre], design);
% stat{3,1}.orgdim = orgsize;


