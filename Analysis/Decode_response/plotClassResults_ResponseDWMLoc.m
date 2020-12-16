%% Plot accuracy of response decoder
% trained and tested using data from digit working memory (DWM)
% task (button pressing with delayed response).
% Note this task isn't included in our paper.
% Decoding analysis itself performed in Classify_Response_DWM.m and 
% saved as mat file. 
% This script loads that file, does all stats and plotting. 
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
figpath = fullfile(exp_path,'figs');
addpath(fullfile(exp_path,'Analysis','stats_code'))
addpath(fullfile(exp_path,'Analysis','stats_code','bayesian-prevalence','matlab'))

% names of the ROIs 
ROI_names = {'V1','V2','V3','V3AB','hV4','IPS0','IPS1','IPS2','IPS3','LO1','LO2',...
    'S1','M1','PMc',...
    'IFS', 'AI-FO', 'iPCS', 'sPCS','sIPS','ACC-preSMA','M1/S1 all'};

% Indices into "ROI_names" corresponding to visual ROIs and motor ROIs
% reordering them a little for logical x-axis on plots
plot_order1 = [1:5,10,11,6:9,12:14];  
% Indices for Multiple-demand ROIs (not included in any of our main 
% analyses, but can plot results for these separately if you wish).
plot_order2 = [15:20]; 

plotVisMotorAcc = 1;    % make plots for retinotopic and motor ROIs?
plotMDAcc=1;    % make plots for MD ROIs?

vismotor_names = ROI_names(plot_order1);
md_names = ROI_names(plot_order2);
plot_order_all = [plot_order1,plot_order2];
nROIs = length(plot_order_all);
vismotor_inds = find(ismember(plot_order_all,plot_order1));
md_inds = find(ismember(plot_order_all,plot_order2));

nVox2Use = 10000;
nPermIter=1000;
chance_val=0.5;
class_str = 'normEucDist';

% parameters for plotting/stats
alpha_vals=[0.05, 0.01, 0.001];
alpha_ms = [8,16,24];
alpha = alpha_vals(1);

acclims = [0.4, 0.9];
dprimelims = [-0.2, 1.4];
col = viridis(4);
col=col(2,:);

diff_col=[0.5, 0.5, 0.5];

condLabStrs = {'DWMLocTask'};
nConds = length(condLabStrs);

%% load results

acc_allsubs = nan(nSubj,nROIs,nConds);
accrand_allsubs = nan(nSubj,nROIs,nConds,nPermIter);
d_allsubs = nan(nSubj,nROIs,nConds);

for ss=1:length(sublist)

    substr = sprintf('S%02d',sublist(ss));
    
    
    save_dir = fullfile(curr_dir,'Decoding_results');
    fn2load = fullfile(save_dir,sprintf('ClassifyResponse_TrnTestDWMLoc_%s_%dvox_%s.mat',class_str,nVox2Use,substr));
    load(fn2load);
    
    assert(size(allacc,1)==numel(ROI_names))
    acc_allsubs(ss,:,:) = squeeze(allacc(plot_order_all,:));
    d_allsubs(ss,:,:) = squeeze(alld(plot_order_all,:));
    
    accrand_allsubs(ss,:,:,:) = squeeze(allacc_rand(plot_order_all,:,:));
   
end

assert(~any(isnan(acc_allsubs(:))))
assert(~any(isnan(d_allsubs(:))))

% get some basic stats to use for the plots and tests below
vals = acc_allsubs;
meanvals = squeeze(mean(vals,1))';
semvals = squeeze(std(vals,[],1)'./sqrt(nSubj));
randvals = accrand_allsubs;

inds2test = ~isnan(squeeze(accrand_allsubs(1,:,1,1)));

% print mean and sem decoding acc for each region of interest
array2table([meanvals(vismotor_inds,1), semvals(vismotor_inds,1)],...
    'RowNames',vismotor_names,'VariableNames',{'mean','sem'})

%% Wilcoxon signed rank test
% for each permutation iteration, use this test to compare real data for all subj to
% shuffled data for all subj.
stat_iters_sr = nan(nROIs, nConds, nPermIter); 
v2do=find(inds2test);
for vv=v2do
    for cc=1:nConds
        x = vals(:,vv,cc);
        for ii=1:nPermIter
            y = randvals(:,vv,cc,ii);
            % compare the real values against the null, for this iteration.
            % w>0 means real>null, w<0 means real<null, w=0 means equal
            stat_iters_sr(vv,cc,ii) = signrank_MMH(x,y);

        end
    end
end

% final p value is the proportion of iterations where null was at least as
% large as the real (e.g. the test stat was 0 or negative)
p_sr = mean(stat_iters_sr<=0, 3);
p_sr(~inds2test) = 100;
is_sig=p_sr<alpha;

% print out how many which areas and conditions are significant across all
% subs
array2table([p_sr(vismotor_inds,1)],...
    'RowNames',vismotor_names,'VariableNames',{'pval'})

%% compute individual subject significance of decoding
vals = acc_allsubs;
randvals = accrand_allsubs;
% finally get p-values based on how often real<random
p_ss = mean(repmat(vals,1,1,1,nPermIter)<randvals,4);
is_sig_ss = p_ss<alpha;    % one tailed test

% print out how many subjects were individually significant for each area
array2table(squeeze(sum(is_sig_ss(:,vismotor_inds),1))','RowNames',vismotor_names,'VariableNames',condLabStrs)

 %% plot with single subjects
bw=0.50;
fs=14;
if plotVisMotorAcc
   
    meanVals=meanvals(vismotor_inds,:);
    seVals=semvals(vismotor_inds,:);
    
    sub_colors = gray(nSubj+1);
    set(groot,'DefaultLegendAutoUpdate','off');
    fh = figure();hold on;
    % first make the actual bar plot
    b = bar(gca,meanVals);
    lh=[b(1)];
    
    % have to set this to "modal", otherwise it fails to get the XOffset
    % property.
    set(fh, 'WindowStyle','modal','WindowState','minimized')
    bar_offset = [b.XOffset];
    barPos = repmat((1:size(meanVals,1))', 1, length(bar_offset)) + repmat(bar_offset, size(meanVals,1), 1);
    for cc=1:nConds
        b(cc).FaceColor = col(cc,:);
        b(cc).EdgeColor = col(cc,:);
        errorbar(barPos(:,cc),meanVals(:,cc),seVals(:,cc),'Marker','none',...
                'LineStyle','none','LineWidth',1,'Color',[0,0,0]);
    end

    set(gca,'XTick', 1:numel(vismotor_inds))
    set(gca,'XTickLabel', vismotor_names,'XTickLabelRotation',90);
    ylabel('Accuracy')
    set(gca,'YLim',acclims)
    set(gca,'XLim',[0,numel(vismotor_inds)+1])
    if chance_val~=0
        line([0,numel(vismotor_inds)+1],[chance_val,chance_val],'Color','k');
    end
    set(gca,'FontSize',fs);
    set(gcf,'Position',[800,800,1200,500]);
    % get locations of bars w offsets
    c=get(gcf,'Children');b=get(c(end),'Children');
   
    verspacerbig = range(acclims)/50;
    horspacer = abs(diff(bar_offset))/2;
%     
    for vv=1:numel(vismotor_inds)
        % add individual subjects
        for ss=1:nSubj
            subvals = squeeze(acc_allsubs(ss,vismotor_inds(vv),:));
            h=plot(vv+bar_offset,subvals,'.-','Color',sub_colors(5,:),'LineWidth',1.5);
            uistack(h,'bottom');
        end
        % add significance of individual areas/conditions
        for cc=1:nConds
            for aa=1:numel(alpha_vals)
                if p_sr(vv,cc)<alpha_vals(aa)
                    % smaller dots get over-drawn with larger dots
                    plot(vv+bar_offset(cc), meanVals(vv,cc)+seVals(vv,cc)+verspacerbig,'.','Color','k','MarkerSize',alpha_ms(aa))
                end
            end
        end
        
    end
    b(end).BarWidth=bw;
    
    leg=legend(lh,{'DWM Loc Task','p<0.05','0<0.01','p<0.001'},'Location','EastOutside');
    set(gcf,'color','white')
    set(gcf, 'WindowStyle','normal','WindowState','normal')

end


%% make a bar plot of acc - md areas
if plotMDAcc
    
    
    meanVals=meanvals(md_inds,:);
    seVals=semvals(md_inds,:);
    
    sub_colors = gray(nSubj+1);
    set(groot,'DefaultLegendAutoUpdate','off');
    fh = figure();hold on;
    % first make the actual bar plot
    b = bar(gca,meanVals);
    lh=[b(1)];
    
    % have to set this to "modal", otherwise it fails to get the XOffset
    % property.
    set(fh, 'WindowStyle','modal','WindowState','minimized')
    bar_offset = [b.XOffset];
    barPos = repmat((1:size(meanVals,1))', 1, length(bar_offset)) + repmat(bar_offset, size(meanVals,1), 1);
    for cc=1:nConds
        b(cc).FaceColor = col(cc,:);
        b(cc).EdgeColor = col(cc,:);
        errorbar(barPos(:,cc),meanVals(:,cc),seVals(:,cc),'Marker','none',...
                'LineStyle','none','LineWidth',1,'Color',[0,0,0]);
    end

    set(gca,'XTick', 1:numel(md_inds))
    set(gca,'XTickLabel', md_names,'XTickLabelRotation',90);
    ylabel('Accuracy')
    set(gca,'YLim',acclims)
    set(gca,'XLim',[0,numel(md_inds)+1])
    if chance_val~=0
        line([0,numel(md_inds)+1],[chance_val,chance_val],'Color','k');
    end
    set(gca,'FontSize',fs);
    set(gcf,'Position',[800,800,1200,500]);
    % get locations of bars w offsets
    c=get(gcf,'Children');b=get(c(end),'Children');
   
    verspacerbig = range(acclims)/50;
    horspacer = abs(diff(bar_offset))/2;
%     
    for vv=1:numel(md_inds)
        % add individual subjects
        for ss=1:nSubj
            subvals = squeeze(acc_allsubs(ss,md_inds(vv),:));
            h=plot(vv+bar_offset,subvals,'.-','Color',sub_colors(5,:),'LineWidth',1.5);
            uistack(h,'bottom');
        end
        % add significance of individual areas/conditions
        for cc=1:nConds
            for aa=1:numel(alpha_vals)
                if p_sr(vv,cc)<alpha_vals(aa)
                    % smaller dots get over-drawn with larger dots
                    plot(vv+bar_offset(cc), meanVals(vv,cc)+seVals(vv,cc)+verspacerbig,'.','Color','k','MarkerSize',alpha_ms(aa))
                end
            end
        end
        
    end
    b(end).BarWidth=bw;
    
    leg=legend(lh,{'DWM Loc Task','p<0.05','0<0.01','p<0.001'},'Location','EastOutside');
    set(gcf,'color','white')
    set(gcf, 'WindowStyle','normal','WindowState','normal')


end

