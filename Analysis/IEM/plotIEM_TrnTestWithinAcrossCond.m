%% plot reconstruction fidelity 
% inverted encoding model trained either within one task condition or
% trained on one task condition/tested on other.
% see how much model is impaired when generalize across conds.
%%
clear
close all;

sublist = [2:7];
nSubj = length(sublist);
% find my root directory - up a few dirs from where i am now
curr_dir = pwd;
filesepinds = find(curr_dir==filesep);
nDirsUp = 2;
exp_path = curr_dir(1:filesepinds(end-nDirsUp+1));

% names of the ROIs 
ROI_names = {'V1','V2','V3','V3AB','hV4','IPS0','IPS1','IPS2','IPS3','LO1','LO2',...
       'S1','M1','PMc',...
    'IFS', 'AI-FO', 'iPCS', 'sPCS','sIPS','ACC-preSMA','M1/S1 all','IPS0-3','IPS0-1','IPS2-3'};

% Indices into "ROI_names" corresponding to visual ROIs and motor ROIs
% reordering them a little for logical x-axis on plots
plot_order1 = [1:5,10,11,6:9,12:14];  
% Indices for Multiple-demand ROIs (not included in any of our main 
% analyses, but can plot results for these separately if you wish).
plot_order2 = [15:20];

vismotor_names = ROI_names(plot_order1);
md_names = ROI_names(plot_order2);
plot_order_all = [plot_order1,plot_order2];
vismotor_inds = find(ismember(plot_order_all,plot_order1));
md_inds = find(ismember(plot_order_all,plot_order2));
nROIs = length(plot_order_all);

ylims_fid = [-0.1, 0.25];

condLabStrs = {'Trn/Test Predictable','Trn/Test Random','Trn Random/Test Predictable','Trn Predictable/Test Random'};
nConds = 2;

chance_val=0;

plotVisFid = 1; % plot all four trn/test combinations for each area?
plotVisFidAvg=1; % average over both within-cond and both across-cond schemes?
plotMDFid=0;
plotMDFidAvg=0;

diff_col=[0.5, 0.5, 0.5];
ms=10;  % marker size for significance dots
%% load results
nTrialsTotal = 400;

fid_allsubs = nan(nSubj,nROIs,nConds,2);    % last dim is trained on data from same or opp condition

condlabs_allsubs = nan(nSubj, nTrialsTotal);

for ss=1:length(sublist)
    
    substr = sprintf('S%02d',sublist(ss));    
    fn = fullfile(exp_path,'Analysis','IEM','IEM_results',sprintf('TrnTestWithinConds_%s.mat',substr));
    load(fn);
    assert(numel(allchanresp)==numel(ROI_names));
    allchanresp_within=allchanresp;
    
    fn = fullfile(exp_path,'Analysis','IEM','IEM_results',sprintf('TrnTestAcrossConds_%s.mat',substr));
    load(fn);
    assert(numel(allchanresp)==numel(ROI_names));
    allchanresp_across=allchanresp;
    
    condlabs = allchanresp_within(1).condLabs;
    assert(all(allchanresp_across(1).condLabs==condlabs));
    
    for vv=1:nROIs
        
       if plot_order_all(vv)>length(allchanresp) || isempty(allchanresp(plot_order_all(vv)).chan_resp_shift) 
           fprintf('skipping %s for S%s because no voxels\n', ROI_names{plot_order_all(vv)}, substr);
           continue
       end
       for cc = 1:nConds
           
           % take out trials from one condition at a time
           theserecs = allchanresp_within(plot_order_all(vv)).chan_resp_shift(condlabs==cc,:);           
           % get the fidelity
           angs = abs((1:360)-180);
           cos_vals = cosd(angs);
           fid_allsubs(ss,vv,cc,1) = mean(cos_vals.*mean(theserecs,1));
           
           % take out trials from one condition at a time
           theserecs = allchanresp_across(plot_order_all(vv)).chan_resp_shift(condlabs==cc,:);           
           % get the fidelity
           angs = abs((1:360)-180);
           cos_vals = cosd(angs);
           fid_allsubs(ss,vv,cc,2) = mean(cos_vals.*mean(theserecs,1));

       end
    end
    
end

assert(~any(isnan(fid_allsubs(:))))

%% More Stats
vals = fid_allsubs;
meanvals = squeeze(mean(vals,1));
semvals = squeeze(std(vals,[],1)./sqrt(nSubj));

%% make a bar plot of acc - visual areas
col = gray(6);
col= col(1:4,:);
if plotVisFid
    
    mean_plot = [meanvals(vismotor_inds,:,1),meanvals(vismotor_inds,:,2)];
    sem_plot = [semvals(vismotor_inds,:,1),semvals(vismotor_inds,:,2)];
   
    plot_barsAndStars(mean_plot,sem_plot,[],...
        [],chance_val,ylims_fid,vismotor_names,condLabStrs,...
        'Fidelity','Spatial Memory Position',col)
    set(gcf,'Position',[800,800,1200,420])
    
end

%%
col = gray(3);
col= col(1:2,:);

if plotVisFidAvg
    
    vals = mean(fid_allsubs(:,vismotor_inds,:,:),3);
    mean_plot = squeeze(mean(vals,1));
    sem_plot = squeeze(std(vals,[],1)./sqrt(nSubj));
    plot_barsAndStars(mean_plot,sem_plot,[],...
        [],chance_val,ylims_fid,vismotor_names,{'Within','Across'},...
        'Fidelity','Spatial Memory Position',col)
    set(gcf,'Position',[800,800,1200,420])
    
end

%% make a bar plot of acc - md areas
col = gray(6);
col= col(1:4,:);
if plotMDFid
    
    mean_plot = [meanvals(md_inds,:,1),meanvals(md_inds,:,2)];
    sem_plot = [semvals(md_inds,:,1),semvals(md_inds,:,2)];
   
    plot_barsAndStars(mean_plot,sem_plot,[],...
        [],chance_val,ylims_fid,md_names,condLabStrs,...
        'Fidelity','Spatial Memory Position',col)
    set(gcf,'Position',[800,800,1200,420])
end

%%
col = gray(3);
col= col(1:2,:);

if plotMDFidAvg
    vals = mean(fid_allsubs(:,md_inds,:,:),3);
    mean_plot = squeeze(mean(vals,1));
    sem_plot = squeeze(std(vals,[],1)./sqrt(nSubj));
    plot_barsAndStars(mean_plot,sem_plot,[],...
        [],chance_val,ylims_fid,md_names,{'Within','Across'},...
        'Fidelity','Spatial Memory Position',col)
    set(gcf,'Position',[800,800,1200,420])
end