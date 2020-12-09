% MMH 8/27/20
% classifying the orientation of the disk boundary. Ignoring which
% luminance value corresponded to which side - bin the orientations (0-180)
% into 4 bins (0,45,90,135) and do binary classification between 0 vs 90,
% and 45 vs 135. Average these two decoding results.
% note that the labels used here are for the FINAL disk boundary - so for
% the random conditon, this should fail by definition.
%%
clear
close all;

sublist = [2:7];
% find my root directory - up a few dirs from where i am now
curr_dir = pwd;
filesepinds = find(curr_dir==filesep);
nDirsUp = 2;
exp_path = curr_dir(1:filesepinds(end-nDirsUp+1));

% nVox2Use = 100;
nVox2Use=10000;
nPermIter=1000;

condLabStrs = {'Predictable','Random'};
nConds = length(condLabStrs);

class_str = 'normEucDist';
% class_str = 'svmtrain_lin';

dbstop if error
numcores = 8;
if isempty(gcp('nocreate'))
    parpool(numcores);
end
rndseed = 133435;
rng(rndseed,'twister');
%% loop over subjects
for ss=1:length(sublist)

    substr = sprintf('S%02d',sublist(ss));
    
    fn2load = fullfile(exp_path,'Samples',sprintf('MainTaskSignalByTrial_%s.mat',substr));
    load(fn2load);
    save_dir = fullfile(curr_dir,'Decoding_results');
    if ~isfolder(save_dir)
        mkdir(save_dir);
    end
    fn2save = fullfile(save_dir,sprintf('ClassifyBoundary_TRbyTR_%s_%dvox_%s.mat',class_str,nVox2Use,substr));

    areas2test = [];
   
    for vv = 1:length(mainSig)

        %% pull out the data for main task

        if length(mainSig)<vv || isempty(mainSig(vv).dat_avg) || size(mainSig(vv).dat_avg,2)<1
            fprintf('skipping area %s because not enough voxels\n',ROI_names{vv})
            continue
        end
        
        for cc = 1:nConds
            
            if cc==1
                boundLabs = mainSig(vv).boundPos;
            else
                boundLabs = mainSig(vv).randBoundPos;
            end
            condLabs = mainSig(vv).condLabs;
            runLabs = mainSig(vv).runLabs;
            % getting rid of any trials with no response here
            % also taking out just the relevant condition!!
            trials2use = condLabs==cc;
            
            boundLabs = boundLabs(trials2use);
            % only want boundary ORIENTATION here, so 90/270 are same
            boundLabs = round(mod(boundLabs,180),1);
            mainDat = mainSig(vv).dat_by_TR;
            mainDat = mainDat(trials2use,:,:);
            nTRs_out = size(mainDat,2);
            
            % bin these for classifier - want 4 bins that are roughly centered at
            % 0, 45, 90, 135.
            binLabs = zeros(size(boundLabs));
            nbins=4;
            bin_centers=[0,45,90,135];
%             axis_spacing=3.6;
%             nDegrees=360;
%             orient_space_bound = axis_spacing/2:axis_spacing:nDegrees;
    
            bin_size=diff(bin_centers(1:2));
            for bb=1:nbins
                inds_this_bin = abs(boundLabs-(bin_centers(bb)-0.0001))<bin_size/2 | abs((boundLabs-180)-(bin_centers(bb)-0.0001))<bin_size/2;
                binLabs(inds_this_bin) = bb;
            end
            assert(~any(binLabs==0))
            
            % subtract mean over voxels 
            mainDat = mainDat - repmat(mean(mainDat,2), 1, size(mainDat, 2));

            if vv==1 && cc==1
                % preallocate array here
                % ngroups is the two binary classifications that get done -
                % 0 versus 90, and 45 versus 135
                nGroups=2;
                allacc = nan(length(ROI_names), nConds, nGroups, nTRs_out);
                alld = nan(length(ROI_names), nConds, nGroups, nTRs_out);
                allacc_rand = nan(length(ROI_names), nConds, nGroups, nTRs_out, nPermIter);
                alld_rand = nan(length(ROI_names), nConds, nGroups, nTRs_out, nPermIter);
            end
            
            % doing cross-validation over sessions here, becuase this keeps
            % the training sets perfectly balanced.
            sessLabs = ones(size(runLabs));
            sessLabs(runLabs>10) = 2;
            
            cvLabs = sessLabs(trials2use);
%             cvLabs=runLabs(trials2use);
%             
            nCV = numel(unique(cvLabs));
            
            for tr=1:nTRs_out

                dat2use = squeeze(mainDat(:,tr,:));

                %% voxel selection from each training set 
                % for this voxel selection I'm using trials from all conditions, but
                % leaving out one session at a time. This gives a list of voxels to use
                % for each fold of cross validation. The same voxels are used
                % regardless of which condition we are using for classification. Think
                % this makes the condition comparisons more fair. Also saves time
                % because we only need to run this once.
                if ~isempty(nVox2Use) && nVox2Use<size(dat2use,2)
                    fprintf('running voxel selection f-test for %s %s - %s condition\n',substr, ROI_names{vv}, condLabStrs{cc})
                    voxStatTable = zeros(size(dat2use,2),nCV);
                    for rr = 1:nCV
                        inds = cvLabs~=rr;
                        pvals = zeros(size(dat2use,2), 1);
                        dat = dat2use(inds,:);
                        lab = binLabs(inds,:);
                        parfor vx = 1:size(dat2use,2)
                             % choose the voxels        
                           [pvalue, stats] = anovan(dat(:,vx), lab,'display','off');
                           pvals(vx) = pvalue;
                        end 
                        voxStatTable(:,rr) = pvals;
                    end
                    nVox2Use_now = nVox2Use;
                else            
                    % put in a placeholder here because using all voxels
                    voxStatTable = zeros(size(dat2use,2),nCV);
                    nVox2Use_now = [];
                end

                % going to do two different classifications - bin 1 versus bin 3,
                % and bin 2 versus bin 4
                groups = [1,3;2,4];
                for xx = 1:2

                    inds2use = binLabs==groups(xx,1) | binLabs==groups(xx,2);

                    %% define train and test set 

                    % same data here because we're not cross-generalizing or anything
                    trnDat = dat2use(inds2use,:);
                    trnLabs = binLabs(inds2use,:);
                    trnCV = cvLabs(inds2use,:);

                    tstDat = dat2use(inds2use,:);
                    tstLabs = binLabs(inds2use,:);
                    tstCV = cvLabs(inds2use,:);

                    %% run the classifier w/ balancing if needed


                    [~,~,predLabs] = my_classifier_cross(trnDat,trnLabs,...
                        trnCV,tstDat, tstLabs,...
                        tstCV,class_str,100,nVox2Use_now,voxStatTable,1);

                    acc = mean(predLabs==tstLabs);
                    dprime = get_dprime(predLabs, tstLabs,tstLabs);

                    allacc(vv,cc,xx,tr) = acc;
                    alld(vv,cc,xx,tr) = dprime;

                    %% do permutation test
                    if ismember(vv,areas2test)
                        fprintf('%s %s cc=%d, xx=%d tr=%d, performance on real data is %.2f, starting random shuffles over %d iters...\n',...
                        substr,ROI_names{vv},cc,xx,tr,allacc(vv,cc,xx,tr),nPermIter)

                        % now doing the permutation test, shuffle labels 1000 times.
                        randaccs= nan(nPermIter, 1);              
                        randd = nan(nPermIter, 1);

                        parfor ii=1:nPermIter
                            % randomize all labels (note this is across all runs,
                            % so we're shuffling training and testing sets at once.
                            randlabs_all=nan(size(trnLabs));
                            assert(numel(unique(trnCV))==2)
                            for se=1:2
                                % shuffle the data from one session at a time, so we
                                % don't un-balance the training sets. 
                                inds=trnCV==se;
                                dat2shuff=trnLabs(inds);
                                randlabs_all(inds) = dat2shuff(randperm(numel(dat2shuff)));
                            end             
                            % run classifier with the random labels
                            [~,~,predLabs] = my_classifier_cross(trnDat,randlabs_all,...
                            trnCV,tstDat, randlabs_all,...
                            tstCV,class_str,100,nVox2Use_now,voxStatTable,1);

                            % get performance in each condition, for the random decoder
                            randaccs(ii) = mean(predLabs==randlabs_all);                  
                            randd(ii) = get_dprime(predLabs,randlabs_all,unique(randlabs_all));

                        end
                    else
                        fprintf('%s %s cc=%d, xx=%d, tr=%d, performance on real data is %.2f, skipping permutation test...\n',...
                        substr,ROI_names{vv},cc,xx,tr,allacc(vv,cc,xx,tr))
                        randaccs= nan(nPermIter, 1);              
                        randd = nan(nPermIter, 1);
                    end

                    % put everything into a big array for saving
                    allacc_rand(vv,cc,xx,tr,:) = randaccs;               
                    alld_rand(vv,cc,xx,tr,:) = randd;
                    
                end
            end
        end
        

    end

    fprintf('saving to %s\n',fn2save);
    save(fn2save,'allacc','alld','allacc_rand','alld_rand');

end