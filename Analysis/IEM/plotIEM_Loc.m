%% plot reconstructions 
% training/testing on SPATIAL POSITION localizer, check to make sure we
% can get reasonable reconstruction fidelity in this task.
%%
clear
close all;

sublist = [2:7];
nSubj = length(sublist);
% find my root directory - up a few dirs from where i am now
mypath = pwd;
filesepinds = find(mypath==filesep);
nDirsUp = 2;
exp_path = mypath(1:filesepinds(end-nDirsUp+1));

% names of the ROIs 
ROI_names = {'V1','V2','V3','V3AB','hV4','IPS0','IPS1','IPS2','IPS3','LO1','LO2',...
     'S1','M1','PMc',...
    'IFS', 'AI-FO', 'iPCS', 'sPCS','sIPS','ACC-preSMA','M1/S1 all'};

nROIs = length(ROI_names);
% Indices into "ROI_names" corresponding to visual ROIs and motor ROIs
% reordering them a little for logical x-axis on plots
plot_order1 = [1:5,10,11,6:9,12:14];  
% Indices for Multiple-demand ROIs (not included in any of our main 
% analyses, but can plot results for these separately if you wish).
plot_order2 = [15:20]; 
visual_names = ROI_names(plot_order1);
md_names = ROI_names(plot_order2);
plot_order_all = [plot_order1, plot_order2];
vis_inds = find(ismember(plot_order_all,plot_order1));
md_inds = find(ismember(plot_order_all,plot_order2));

plotVisualRecons = 1;
plotVisualFids = 1;
plotMDRecons = 0;
plotMDFids = 0;

nVOIs = length(plot_order_all);

ylims = [-5, 13];
ylims_fid = [-0.1, 4];


%%
for ss=1:nSubj
    
    substr = sprintf('S%02d',sublist(ss));    
    fn = fullfile(exp_path,'Analysis','IEM','IEM_results',sprintf('TrnTestWithinLoc_%s.mat',substr));
    load(fn);

    if ss==1        
        %preallocate some arrays       
        avg_recs = nan(nSubj, nVOIs, length(xx));
        fidelity = nan(nSubj, nVOIs);
    end
    assert(numel(allchanresp)==numel(ROI_names));
    %% load recons from each area
    for vv=1:nVOIs
      
       if plot_order_all(vv)>length(allchanresp) || isempty(allchanresp(plot_order_all(vv)).chan_resp_shift) 
           fprintf('skipping %s for %s because no voxels\n', ROI_names{plot_order_all(vv)}, substr);
           continue
       end
       
       theserecs = allchanresp(plot_order_all(vv)).chan_resp_shift;
       avg_recs(ss,vv,:) = mean(theserecs,1); 

       % get the fidelity
       angs = abs((1:360)-180);
       cos_vals = cosd(angs);
       fidelity(ss,vv) = mean(cos_vals.*mean(theserecs,1));
                 
       if ss>1 && fidelity(ss-1,vv)==fidelity(ss,vv)
           error('you have a missing value and something bad is happening')
       end
    end
  
end

%% make plots: recons in visual ROIs
col = plasma(3);
cc=1;

if plotVisualRecons
    figure;hold all;
   
    % plot each subject and ROI as a separate subplot.
    for ss = 1:nSubj
        for vv = 1:numel(vis_inds)
            
            subplot(nSubj+1,numel(vis_inds),(ss-1)*numel(vis_inds)+vv);hold all;
            
            plot(xx,squeeze(avg_recs(ss,vis_inds(vv),:)),'Color',col(cc,:),'LineWidth',1);
       
            set(gca, 'FontSize', 12)
            set(gca,'XTick',[]);
            set(gca,'YLim',ylims);
%             set(gca, 'XLim', [0, 360],'XTick',[0:180:360],'XTickLabel',{-180:180:180}, 'YLim',ylims)
            ylims = get(gca, 'YLim');
            plot([shift_to shift_to], ylims, 'k', 'LineWidth', 1)
            if vv ==1
                ylabel(sprintf('S%02d',sublist(ss)));
            end

            if ss==1
                if contains(visual_names{vv}, ' ')
                    % break it into two strings 
                    spaceind = find(visual_names{vv}==' ');
                    title(sprintf('%s\n%s', visual_names{vv}(1:spaceind-1), visual_names{vv}(spaceind+1:end)));
                else               
                    title(sprintf('%s', visual_names{vv}));
                end
            end
            set(gcf,'Color','w')
        end
    end
    % now plot the average across subjects.
    for vv = 1:numel(vis_inds)
            
        subplot(nSubj+1,numel(vis_inds),(nSubj)*numel(vis_inds)+vv);hold all;
      
        recs = squeeze(avg_recs(:,vis_inds(vv),:));
        if nSubj>1
            meanvals = nanmean(recs,1);
        else
            meanvals = recs;
        end
        errorbar(xx',meanvals,[], 'Color',col(cc,:),'LineWidth',1);
        
        set(gca, 'FontSize', 12)
        if vv==1
            set(gca, 'XLim', [0, 360],'XTick',[0:180:360],'XTickLabel',{-180:180:180}, 'YLim',ylims)
        else
            set(gca,'XTick',[]);
            set(gca,'YLim',ylims);
        end
        ylims = get(gca, 'YLim');
        plot([shift_to shift_to], ylims, 'k', 'LineWidth', 1)
        if vv ==1
            ylabel('Average');           
            ylabel('Avg');
            xlabel('Orientation Channel')    
        end

        set(gcf,'Color','w')
    end
    suptitle('Train/Test Localizer')
    set(gcf,'Position',[200,200,1400,800]);
end

%% make plots: recons in motor/MD ROIs
 
if plotMDRecons
    figure;hold all;
    col = viridis(3);
    cc=1;
    % plot each subject and ROI as a separate subplot.
    for ss = 1:nSubj
        for vv = 1:numel(md_inds)
            
            subplot(nSubj+1,numel(md_inds),(ss-1)*numel(md_inds)+vv);hold all;
            
            plot(xx,squeeze(avg_recs(ss,md_inds(vv),:)),'Color',col(cc,:),'LineWidth',1);
       
            set(gca, 'FontSize', 12)
            set(gca,'XTick',[]);
            set(gca,'YLim',ylims);
%             set(gca, 'XLim', [0, 360],'XTick',[0:180:360],'XTickLabel',{-180:180:180}, 'YLim',ylims)
            ylims = get(gca, 'YLim');
            plot([shift_to shift_to], ylims, 'k', 'LineWidth', 1)
            if vv ==1
                ylabel(sprintf('S%02d',sublist(ss)));
            end

            if ss==1
                if contains(md_names{vv}, ' ')
                    % break it into two strings 
                    spaceind = find(md_names{vv}==' ');
                    title(sprintf('%s\n%s', md_names{vv}(1:spaceind-1), md_names{vv}(spaceind+1:end)));
                else               
                    title(sprintf('%s', md_names{vv}));
                end
            end
            set(gcf,'Color','w')
        end
    end
    % now plot the average across subjects.
    for vv = 1:numel(md_inds)
            
        subplot(nSubj+1,numel(md_inds),(nSubj)*numel(md_inds)+vv);hold all;
      
        recs = squeeze(avg_recs(:,md_inds(vv),:));
        if nSubj>1
            meanvals = nanmean(recs,1);
        else
            meanvals = recs;
        end
        errorbar(xx',meanvals,[], 'Color',col(cc,:),'LineWidth',1);
      
        set(gca, 'FontSize', 12)
        if vv==1
            set(gca, 'XLim', [0, 360],'XTick',[0:180:360],'XTickLabel',{-180:180:180}, 'YLim',ylims)
        else
            set(gca,'XTick',[]);
            set(gca,'YLim',ylims);
        end
        ylims = get(gca, 'YLim');
        plot([shift_to shift_to], ylims, 'k', 'LineWidth', 1)
        if vv ==1
            ylabel('Average');           
            ylabel('Avg');
            xlabel('Orientation Channel')    
        end

        set(gcf,'Color','w')
    end
    
    suptitle('Train/Test Localizer')
    set(gcf,'Position',[200,200,1400,800]);
end


%% plot fidelity - visual

if plotVisualFids
    
    vals = fidelity(:,vis_inds);
    if nSubj>1
        meanvals = squeeze(nanmean(vals,1));
        semvals = squeeze(nanstd(vals,[],1)./sqrt(sum(~isnan(vals),1)));
    else
        meanvals = vals;
        semvals =[];
    end
    
    plot_barsAndStars(meanvals',semvals',[],[],[],ylims_fid,visual_names,[],'Fidelity','Train/Test Spatial Localizer',col(cc,:))
  
end

%% plot fidelity - motor
if plotMDFids
    
    vals = fidelity(:,md_inds);
    if nSubj>1
        meanvals = squeeze(nanmean(vals,1));
        semvals = squeeze(nanstd(vals,[],1)./sqrt(sum(~isnan(vals),1)));
    else
        meanvals = vals;
        semvals =[];
    end
    
    plot_barsAndStars(meanvals',semvals',[],[],[],ylims_fid,md_names,[],'Fidelity','Train/Test Spatial Localizer',col(cc,:))
  
end