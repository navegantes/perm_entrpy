%
close all;
clear;
clc;

datapath = 'D:\Users\NFB\Pacientes\';
% rootpath = 'E:\Datas\nfb-data';
rootpath = 'D:\Users\Sources\Entropy\perm_entropy';
scriptspath = 'D:\Users\Sources\Entropy\perm_entropy';

% chdir(scriptspath);
chdir(rootpath);
addpath('PE');
addpath('functions');

subj_list = ["JLC"]; % ["EYK", "JLC", "JRJ", "SAJ"];
SBJ_DT = struct();

SBJ_DT = fntools.gendatastruct(datapath, SBJ_DT, subj_list );

% % -----------------------------------------------------------------

TASKS = struct();
bs_data = struct();
metrics = struct();

% Parametros cria�ao dos eventos
ev_range = [-.3 .5]; % ms
RWD_chan = 3;
RWD_label = 'RWD-250';
latency = '0<=1800';
ev_duration = '.250<=2'; %(s)
rejspecevent = true; % rejeitar epocas baseado no espectro
% Task slices em segundos
nfb_slice = [60 1860];
bs1_slice = [0 60];
bs2_slice = [1860 1920];

loadsurdata = true;
savesurdata = false;
zscore_norm = false;
savesbjdata = false;

% % -----------------------------------------------------------------

t_slice = [10 1939];
frange = {[4 7] [12 15] [20 30] [8 12]};

for suj=1:length(subj_list)
    filepath = SBJ_DT(suj).filespath;
    
    for sess=1:length(filepath)
        EEG(sess) = init_process(filepath{sess}, t_slice, zscore_norm);

        % % -----------------------------------------------------------------
        % Gera surrogate e calcula entropia permuta��o, inclui no objeto EEG
        splitpath = strsplit(filepath{sess}, {'\'});
        filename = splitpath{end};  % XXX-DDMMAA_Sn
        
        [EEG(sess)] = fntools.pesurdata(EEG(sess), filename, rootpath, loadsurdata, savesurdata);
        
        % -----------------------------------------------------------------
        % |-------|-------------------|----------|------|
        % 0  bs1  60       nfb       1860  bs2  1920   1829
        % Separa trechos baseline
        TASKS(sess).nfb = pop_select( EEG(sess),'time', nfb_slice );
        TASKS(sess).bs1 = pop_select( EEG(sess),'time', bs1_slice );
        TASKS(sess).bs2 = pop_select( EEG(sess),'time', bs2_slice );
        % 12:dados 13:surrogates
        bs_data(sess).bs = { TASKS(sess).nfb.data(12,:,:), TASKS(sess).nfb.data(13,:,:);
                             TASKS(sess).bs1.data(12,:,:), TASKS(sess).bs1.data(13,:,:);
                             TASKS(sess).bs2.data(12,:,:), TASKS(sess).bs2.data(13,:,:) };    

        for bs=1:3
            metrics(sess).corr(bs) = { corrcoef( bs_data(sess).bs{bs,1}, bs_data(sess).bs{bs, 2} )};
            metrics(sess).wass(bs) = ws_distance( bs_data(sess).bs{bs,1}, bs_data(sess).bs{bs, 2} );
        end
        
%         metrics(sess).slopes = 
        
        % Cria os eventos e extrai trials por sessao
        SBJ_DT(suj).events(sess) = fntools.create_events( TASKS(sess).nfb, ...
                                                          RWD_chan, latency, ...
                                                          RWD_label, ev_duration, ...
                                                          ev_range, ...
                                                          filename, rejspecevent); % true - rejspec
        disp("..." +newline+ ...
             "Eventos criados. Sessao: " + string(sess));
        SBJ_DT(suj).bandspower{sess,1} = fntools.calc_bandpower(SBJ_DT(suj).events(sess), frange);
    end

    SBJ_DT(suj).tasks = TASKS;
    SBJ_DT(suj).metrics = metrics;
end

if savesbjdata
    save([rootpath, '\surdatas\sbjdata'], 'SBJ_DT');
end

%% ------------------------------------------------------------------------
% -------------------------------------------------------------------------
% VISUALIZACAO
% -------------------------------------------------------------------------
% Compara��o PE entre baseline Pre, Pos, NFB
% Correla��o e Ws distance
showPEBaselines__(SBJ_DT, rootpath);

%% ------------------------------------------------------------------------
% Compara��o espectro nfb/surrogate (confirmar resultado do feedback)
f_range = [1 45];
chans = [1 11];
time2plotnfb = show_ERPSpec__(SBJ_DT, rootpath, chans, ev_range, f_range);
%% ------------------------------------------------------------------------
% Compara��o espectro baseline pre-pos
bs_evrange = [0 1];
taskinfo = ["bs1", "specbs1"];
time2plotbs1 = show_ERPSpec__(SBJ_DT, rootpath, chans, bs_evrange, f_range, taskinfo);
taskinfo = ["bs2", "specbs2"];
time2plotbs2 = show_ERPSpec__(SBJ_DT, rootpath, chans, bs_evrange, f_range, taskinfo);


% % ------------------------------------------------------------------------
% Mostra espectro potencia PSD
show_PSDSpec__(SBJ_DT, rootpath, chans, f_range);
% % ------------------------------------------------------------------------
taskinfo = ["bs1", "psdbs1"];
show_PSDSpec__(SBJ_DT, rootpath, chans, f_range, taskinfo);
taskinfo = ["bs2", "psdbs2"];
show_PSDSpec__(SBJ_DT, rootpath, chans, f_range, taskinfo);

% % ------------------------------------------------------------------------
% Visualiza PE dado e surrogate por trials;
show_evPETrials__(SBJ_DT, rootpath, ev_range);

% % ------------------------------------------------------------------------
% Boxchart
disp("..." +newline+ "Generating boxplot...");
showBandsBoxchart__(SBJ_DT, rootpath);

disp("..." +newline+ "Visualization done...");

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                TESTES                %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% ------------------------------------------------------------------------

dt = SBJ_DT.events(1);
d = reshape(dt.data(12,:,:),[],1)';
chan = 12;
m=mean(dt.data(12, :,:),3);
mM = minmax(d);
% 0.8556 .8572
% 0.828  .832
pop_erpimage(dt,1, chan,[[]],dt.chanlocs(chan).labels,1,1,{},[],'' , ...
             'yerplabel','H','erp',1, 'renorm', 'no',...
             'limits',[NaN NaN 0.8556 .8572 NaN NaN NaN NaN], ...
             'cbar','on', 'caxis', [mM(1) 1], 'erpstd','on');
%% ------------------------------------------------------------------------
figure
bndPWR = SBJ_DT(1).bandspower;
for sess=1:5
    plot(bndPWR{sess}(:,2), 'o-', 'linewidth', 1.2);
    hold on;
end
hold off;
%% ------------------------------------------------------------------------
% figure data e surrogate por sessao
suj = 1;
for i=1:5
%     data = permute(SBJ_DT(suj).events(i).data(12,:,:), [2 3 1]);
    data = SBJ_DT(suj).events(i).data(12,:,:);
    dtmean = mean(data, 3);
%     setname = SBJ_DT(suj).events(i).setname;
    times = SBJ_DT(suj).events(i).times;
    
    datasur = permute(SBJ_DT(suj).events(i).data(13,:,:), [2 3 1]);
    dtmeansur = mean(datasur, 2);
    
    figure
    plot(times, dtmean,'linewidth',2); %'DisplayName', setname(12:13));
    hold on;
    plot(times, dtmeansur,'linewidth',2); %'DisplayName', setname(12:13));
    hold off;
    legend({'Data', 'Surrogate'});
end
title('Permutation Entropy  Data');
legend('show');
% hold off;
%%
% Mean Permutation Entropy
figure
suj = 1;
for i=1:5
    datasur = SBJ_DT(suj).events(i).data(12,:,:);
    dtmeansur = mean(datasur, 3);
    setname = SBJ_DT(suj).events(i).setname;
    times = SBJ_DT(suj).events(i).times;
    
    plot(times, dtmeansur,'linewidth',2,'DisplayName', setname(12:13));
    hold on;
end
title('Mean Permutation Entropy');
legend('show');
hold off;

%% ------------------------------------------------------------------------
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                LOCAL VIS FUNCTIONS                %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

show_EntrSpecPerm__(SBJ_DT(1), rootpath);
%% ------------------------------------------------------------------------

[SBJ_DT] = show_SlopesAVG__(SBJ_DT);
showCoefsBoxchart__(SBJ_DT, rootpath);
%% ------------------------------------------------------------------------
% marca a posição dos eventos de feedback
showevents(SBJ_DT);
%% ------------------------------------------------------------------------

showCoefsBoxchart__(SBJ_DT, rootpath);
%% ------------------------------------------------------------------------

function showevents(SBJ_DT)

    sess = 2;
    suj  = 1;
    
    dt      = SBJ_DT(suj).tasks(sess).nfb.data(12,:,:);
    times   = SBJ_DT(suj).tasks(sess).nfb.times;
    EEGev   = SBJ_DT(suj).events(sess);
    urevent = EEGev.urevent;
%     pop_eegplot(EEGev,1,1,1);
    
    numevents = length(urevent);
    durations = [urevent.duration];
    lat       = [urevent.latency];
    
    figure;
    plot(times/1000, dt); hold on;
    
    for ev=1:numevents
        if durations(ev)>=64
            val = times(lat(ev))/1000;
            plot(val, dt(lat(ev)), 'og', ...
                'linewidth', .5, ...
                'MarkerFaceColor', 'g', ...
                'MarkerSize',2);
        end
    end
    hold off;
end

function show_EntrSpecPerm__(SBJ_DT, rootpath)
    
    subj_list = [ SBJ_DT.names ];
    
    for suj=1:length(subj_list)
        filepath = SBJ_DT(suj).filespath;
        EEG = SBJ_DT(suj); %.tasks;
        
        offset = 0.1726;
        boxpos = 0.8060;
        
        hfig = figure('Position', [282,132,800,840]);
        for sess=1:length(filepath)
%             time  = EEG(sess).nfb.times;
            splitpath = strsplit(filepath{sess}, {'\'});
            filename = splitpath{end};
            
            subplot(5,1, sess,'Parent',hfig);
            ax = gca;
            annonbox = [0.7552 boxpos 0.1447 0.03214];
            vis.show_hspecperm(EEG, ax, sess, annonbox);
            boxpos = boxpos - offset;
        end
%         vis.savefigure(hfig, rootpath, filename(1:end-3), "specpermh");
%         close(hfig);
    end
end

function [SBJ_DT] = show_SlopesAVG__(SBJ_DT)

    % Slope das medias Permutation Entropy
    subj_list = [ SBJ_DT.names ];
    trange    = [0 250]; % em ms

    for suj=1:length(subj_list)
        numsess      = length(SBJ_DT(suj).filespath);
        dtmeansur    = cell(numsess, 1);
        mpcoefs      = cell(numsess, 1);
        mpolyn       = cell(numsess, 1);
        trialslpcoef = cell(numsess, 1);
        prwdcoefs    = cell(numsess, 1);
        trialpoly    = cell(numsess, 1);
        prwdpolyn    = cell(numsess, 1);

        for sess=1:numsess
            EEGev   = SBJ_DT(suj).events(sess);
            datasur = EEGev.data(12,:,:);
            times   = SBJ_DT(suj).events(sess).times;
            [tslice, tind]  = timeslice(times, trange);
            
            dtmeansur{sess} = mean(datasur, 3);%             [mpcoefs{sess}, mpolyn{sess}, tmslope] = polyslope__(dtmeansur{sess}, times);
            mpcoefs{sess} = polyfit(tslice, dtmeansur{sess,1}(tind(1):tind(2)), 1);
            mpolyn{sess}  = polyval(mpcoefs{sess}, tslice); % + mpcoefs{sess}(2);
            
            [trialslpcoef{sess}, trialpoly{sess}, prwdcoefs{sess}, prwdpolyn{sess}] = calc_slopes(EEGev, tind);
            
            SBJ_DT(suj).metrics(sess).slopecoefs  = trialslpcoef{sess};
            SBJ_DT(suj).metrics(sess).pslopecoefs = prwdcoefs{sess};
            
%             mprwdcoefs = mean(prwdcoefs{sess});
            
%             coefsmean = string(sess) + " COEFSmean:  " + string(mean(trialslpcoef{sess}(:,1)));
%             meancoef  = string(sess) + " MeanCoef :  " + string(mpcoefs{sess}(1));
%             disp(coefsmean);
%             disp(meancoef);
        end
        coefs = {mpcoefs, prwdcoefs};
        polyn = {mpolyn, prwdpolyn, tind};
        slpfig = vis.show_slopesavg(SBJ_DT(suj), coefs, polyn, tslice);
    end
end

function [tslice, tindex] = timeslice(times, trange)
    tzero  = dsearchn(times', trange(1));
    tevend = dsearchn(times', trange(2));
    tindex = [tzero tevend];
    tslice = times(tzero:tevend);
end

function [pcoefs, polyn, prwdcoefs, prwdpolyn] = calc_slopes(EEGev, trange)
    
    petrials  = permute(EEGev.data(12,:,:), [2 3 1]); % (lentime, numtrials)
%     surpetrials = permute(EEGev.data(13,:,:), [2 3 1])';
    times     = EEGev.times;
    tzero     = trange(1);
    tevend    = trange(2);
    numtrials = size(petrials, 2);
    lentime   = (tevend-tzero)+1;
    tslice    = times(tzero:tevend);
    
    pcoefs    = zeros(numtrials, 2);
    prwdcoefs = zeros(numtrials, 2);
    polyn     = zeros(lentime, numtrials); %cell(numtrials, 1);
    prwdpolyn = zeros(tzero, numtrials);
    
    for trial=1:numtrials
%         [pcoefs(trial,:), polyn(:,trial), ~] = polyslope__(petrials(:,trial), times);
        pcoefs(trial,:)    = polyfit(tslice, petrials(tzero:tevend, trial), 1);
        polyn(:,trial)     = polyval(pcoefs(trial,:), tslice); % + pcoefs(trial,2);
        prwdcoefs(trial,:) = polyfit(times(1:tzero), petrials(1:tzero, trial), 1);
        prwdpolyn(:,trial) = polyval(prwdcoefs(trial,:), times(1:tzero));
    end

end

% function [pcoefs, polyn, tmslope] = polyslope__(datasur, times, sloperng)
% 
% %     dtmeansur = mean(datasur, 3);
% 
%     tzero = dsearchn(times', 0);
%     tevend = dsearchn(times', 250);
%     tmslope = times(tzero:tevend);
%     
%     pcoefs = polyfit(tmslope, datasur(tzero:tevend), 1);
%     polyn = pcoefs(1).*tmslope + pcoefs(2);
% 
% end

function showPEBaselines__(SBJ_DT, rootpath)

    subj_list = [ SBJ_DT.names ];

    for suj=1:length(subj_list)
        filepath = SBJ_DT(suj).filespath;
        EEG = SBJ_DT(suj).tasks;
        metrics = SBJ_DT(suj).metrics;

        for sess=1:length(filepath)
            splitpath = strsplit(filepath{sess}, {'\'});
            filename = splitpath{end};
            basefig = vis.show_pebaselines(EEG(sess), metrics(sess));
            vis.savefigure(basefig, rootpath, filename, "pebases");
            close(basefig);
        end
    end
end

function time2plot = show_ERPSpec__(SBJ_DT, rootpath, chans, ev_range, f_range, taskinfo)

    if nargin < 6
        taskinfo = ["nfb", "speccom"];
    end
    
    endlabel = taskinfo(2);
    subj_list = [ SBJ_DT.names ];
    infodata.taskinfo = taskinfo;
    
    for suj=1:length(subj_list)
        
        EEGev = get_taskdata__( SBJ_DT(suj), ev_range, taskinfo(1) );
        infodata.figtitle = { "Original " + upper(taskinfo(1)) + " Data", "Surrogates Data"};
        
        for sess=1:length(SBJ_DT(suj).filespath)
            splitpath = strsplit(SBJ_DT(suj).filespath{sess}, {'\'});
            filename = splitpath{end};
            
            [time2plot, currfig] = vis.show_erpspectrum(EEGev(sess), ...
                                                        EEGev(sess).srate, ...
                                                        ev_range, ...
                                                        f_range, ...
                                                        chans, ...
                                                        infodata );
            
            vis.savefigure(currfig, rootpath, filename, endlabel);
            close(currfig);
        end
    end
end

function EEGev = get_taskdata__(SUJDT, tslice, taskinfo)
    if isempty(taskinfo)
        taskinfo = "nfb";
    end
    
    switch taskinfo
        case "nfb"
            EEGev = SUJDT.events;
            return
        case "bs1"
            bsdt = [ SUJDT.tasks.bs1 ];
        case "bs2"
            bsdt = [ SUJDT.tasks.bs2 ];
        otherwise
            EEGev = SUJDT.events;
            return
    end
    % Cria segmentos, tslice(2) segundos, no baseline selecionado
    for s=1:length(bsdt)
        EEGepch = eeg_regepochs( bsdt(s), 'recurrence', tslice(2), ...
                                  'limits', tslice, ...
                                  'eventtype', 'bsevent');
        EEGepch = fntools.rejtrends(EEGepch);
        EEGev(s) = fntools.rejspec(EEGepch);
    end
end

function show_PSDSpec__(SBJ_DT, rootpath, channels, f_range, taskinfo)

    if nargin < 5
        taskinfo = ["nfb", "psdnfb"];
    end
    
    ev_range = [0 1];
    endlabel = taskinfo(2);
    subj_list = [ SBJ_DT.names ];
    
    for suj=1:length(subj_list)
        filepath = SBJ_DT(suj).filespath;
        EEGev = get_taskdata__( SBJ_DT(suj), ev_range, taskinfo(1) );

        for sess=1:length(filepath)
            splitpath = strsplit(filepath{sess}, {'\'});
            filename = splitpath{end};

            specfig = figure('visible','off');
            pop_spectopo(EEGev(sess), 1, [], 'EEG', ...
                         'freqrange', f_range, ...
                         'plotchans', channels);
            legend('C3 channel','Surrogate');
            
            vis.savefigure(specfig, rootpath, filename, endlabel);
            close(specfig);
        end
    end
end

function show_evPETrials__(SBJ_DT, rootpath, ev_range)

    subj_list = [ SBJ_DT.names ];

    for suj=1:length(subj_list)
        filepath = SBJ_DT(suj).filespath;
        EEGev = SBJ_DT(suj).events;

        for sess=1:length(filepath)
            splitpath = strsplit(filepath{sess}, {'\'});
            filename = splitpath{end};

            pefig = vis.show_evtrials(EEGev(sess), ev_range);
            vis.savefigure(pefig, rootpath, filename, "htrials");
            close(pefig);
        end
    end
end

function showBandsBoxchart__(SBJ_DT, rootpath)
    
    subj_list = [ SBJ_DT.names ];
    bandlabels = {'Theta' 'SMR' 'Hibeta' 'Alpha'};
%     labels = SBJ_DT.filespath;
    
    for suj=1:length(subj_list)
        filename = SBJ_DT(suj).names;
        
        boxfig = vis.gen_boxchart(SBJ_DT(suj), bandlabels);
        
        for band=1:length(bandlabels)
            vis.savefigure(boxfig{band}, rootpath, filename, "box-"+bandlabels{band});
        end
    end
end

function showCoefsBoxchart__(SBJ_DT, rootpath)
    
    subj_list = [ SBJ_DT.names ];
%     bandlabels = {'Theta' 'SMR' 'Hibeta' 'Alpha'};
    
    for suj=1:length(subj_list)
%         filename = SBJ_DT(suj).names;
        aux      = cellfun(@(x) split(x, "_"), SBJ_DT(suj).filespath,'UniformOutput',false);
        labels   = cellfun(@(x) x{2}, aux,'UniformOutput',false);
        
        boxfig = vis.gen_coefsboxchart(SBJ_DT(suj), labels);
        
%         for band=1:length(bandlabels)
%             vis.savefigure(boxfig{band}, rootpath, filename, "box-"+bandlabels{band});
%         end
    end
end

%% ------------------------------------------------------------------------
