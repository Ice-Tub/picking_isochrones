%to fix next
%optimize loop below
%how to start & stop a layer?
%automatically name layers by e.g. profile name and ind below surface pick
%(&maybe by polar x and y)
%automatically zoom into layer
%automatically adjust color bar - by setting the maximum a certain color in

clear all; 
close all;

%TUNING PARAMETERS
window=9; %vertical window, keep small to avoid jumping. Even numbers work as next odd number.
seedthresh=5;% 5 seems to work ok, make bigger to have less, set 0 to take all (but then the line jumps automatically...)
window2=20; %20 slope seems to work, window over which the linear propagation works
%wavelet parameters
wavelet = 'mexh';% choose the wavelet 'mexh' or 'morl' - Mexican Hat (mexh) gives cleaner results 
%wavelet = 'morl';
% define the wavelet scales:
maxwavelet=16; %min is always3, layers size is half the wavelet scale
% decide how many pixels below bed layer is counted as background noise:
%bgSkip = 150; %default is 50 - makes a big difference for m-exh, higher is better
bgSkip = 150;
filename_raw_data = append(pwd,'\TopoallData_20190107_01_003.mat'); % Don't needed if geoinfofile already exists.
filename_geoinfo = append(pwd,'\LayerData_003.mat');
load_crossover = 0; % 1 = yes, 0 = no
filename_crossover = append(pwd,'\TopoallData_20190107_01_006.mat');
MinBinForSurfacePick = 10;% when already preselected, this can be small
smooth=40; %between 30 and 60 seems to be good
%MinBinForBottomPick = 1500; %should be double-checked on first plot (as high as possible)
MinBinForBottomPick = 1800; 
smooth2=60; %smooth bottom pick, needs to be higher than surface pick, up to 200 ok
RefHeight=500; %set the maximum height for topo correction of echogram, extended to 5000 since I got an error in some profiles
rows=1000:5000; %cuts the radargram to limit processing (time) (top and bottom)
clms=1:8268; %for 6 
%%
Bottom = clms*0.0+11e-6; %set initial bottom pick as horizontal line 
%will be overwritten by the following

if isfile(filename_geoinfo) % For programming purposes; save preprocessed file on computer to save time.
    load(filename_geoinfo);
else
    [geoinfo,echogram] = readdata2(filename_raw_data,rows,clms,Bottom); % from ARESELP

    geoinfo.echogram=echogram;

    %pick main reflectors (the bottom pick is very important for background
    %noise associated with mexh wavelet (morl can handle more noise but give less accurate results)
    geoinfo = pick_surface(geoinfo,echogram,MinBinForSurfacePick,smooth);
    geoinfo = pick_bottom(geoinfo,echogram,MinBinForBottomPick,smooth2);

    %make graphic to check main reflectors
    figure(1)
    plotmainpicks(geoinfo,clms)

    %wavelet part
    minscales=3;
    scales = minscales:maxwavelet; % definition from ARESELP
    DIST = (maxwavelet/2); 

    %calculate seedpoints
    [imDat,imAmp, ysrf,ybtm] = preprocessing(geoinfo,echogram);
    peakim = peakimcwt(imAmp,scales,wavelet,ysrf,ybtm,bgSkip); % from ARESELP
    geoinfo.peakim=peakim;
    
    %make logical matrix of seeds 
    geoinfo.seeds = geoinfo.peakim>seedthresh; % 0 or 1 matrix

    [geoinfo.psX,geoinfo.psY] = ll2ps(geoinfo.latitude,geoinfo.longitude); %convert to polar stereographic

    save(filename_geoinfo, 'geoinfo')
end

ind = find(geoinfo.peakim>seedthresh);
[sy,sx]=ind2sub(size(geoinfo.peakim), ind);
[ny nx]=size(geoinfo.echogram);


%seedpt = selectseedpt(geoinfo.peakim); %select seedpoints according to lognormal list, not needed since later we define a threshold
%geolayers = echogram_topo(geolayers,geoinfo,RefHeight);

%%
f = figure(2); % of flat data with seed points
imagesc(mag2db(geoinfo.echogram));
cini = -150;
colormap(jet)
hold on
plot(sx,sy,'r*') % plot seedpoints
set(gcf,'doublebuffer','on');
a = gca;
set(a,'CLim',[cini-50 cini+50]); % Initial color range

apos=get(a,'position');
set(a,'position',[apos(1) apos(2)+0.1 apos(3) apos(4)-0.1]);
bpos=[apos(1) apos(2)-0.05 apos(3)/3 0.05];
cpos=[apos(3)/3+0.15 apos(2)-0.05 0.15 0.05];
dpos=[apos(3)/3+0.32 apos(2)-0.05 0.15 0.05];
epos=[apos(3)/3+0.49 apos(2)-0.05 0.15 0.05];


cmin = round(min(mag2db(geoinfo.echogram),[],'all')+50); 
cmax = round(max(mag2db(geoinfo.echogram),[],'all')-50);

% Create color slider
S = "set(gca,'CLim',[get(gcbo,'value')-50, get(gcbo,'value')+50])";
ui_b = uicontrol('Parent',f,'Style','slider','Units','normalized','Position',bpos,...
              'value',cini,'min',cmin,'max',cmax,'callback',S); % Color slider. Atm it uses fixed max and min values, instead they could be adopted to the file values.
bgcolor = f.Color;
uicontrol('Parent',f,'Style','text','Units','normalized','Position',[bpos(1)-0.05,bpos(2),0.05,bpos(4)],...
                        'String',num2str(cmin),'BackgroundColor',bgcolor);
uicontrol('Parent',f,'Style','text','Units','normalized','Position',[bpos(1)+bpos(3)-0.05,bpos(2),0.05,bpos(4)],...
                'String',num2str(cmax),'BackgroundColor',bgcolor);
uicontrol('Parent',f,'Style','text','Units','normalized','Position',[bpos(1)+bpos(3)/2-0.15,bpos(2)-0.05,0.3,0.05],...
                'String',append('Color range (value ',char(177),' 50)'),'BackgroundColor',bgcolor);

cl = 1; % Set number of current layers
S = "cl = get(gcbo,'value'); try set(layerplot(end),'YData',layers(cl,:)); end";
ui_c = uicontrol('Parent',f,'Style','popupmenu', 'String', {'Layer 1','Layer 2','Layer 3','Layer 4','Layer 5','Layer 6','Layer 7','Layer 8'},'Units','normalized','Position',cpos,...
              'value',cl,'callback',S); % Choose layer.
          
leftright = 1; % Go to left or right. lr = 1 -> right, lr = -1 -> left.
S = "leftright = get(gcbo,'value');";
ui_d = uicontrol('Parent',f,'Style','togglebutton', 'String', 'Go to left','Units','normalized','Position',dpos,...
              'value',leftright,'min',1,'max',-1,'callback',S); % Select to go left or right.
          
selection_active = 1; % Selection active, 1 = yes, 0 = no
S = "selection_active = get(gcbo,'value'); return";
ui_e = uicontrol('Parent',f,'Style','pushbutton', 'String', 'End Selection','Units','normalized','Position',epos,...
              'value',1,'max',0,'callback',S); % Finish selection


%% Figure out cross-overs (load geoinfo3 in this case)
% need to load geoinfo3 manually 

if load_crossover
    geoinfo3 = load(filename_crossover); % added by Falk
    if ~isfield(geoinfo3,'psX') % Check if polar stereographic coordinates not exist in file
        [geoinfo3.psX,geoinfo3.psY] = ll2ps(geoinfo3.latitude,geoinfo3.longitude); %convert to polar stereographic
    end

    [xi,yi] = polyxpoly(geoinfo.psX,geoinfo.psY,geoinfo3.psX,geoinfo3.psY); %selecting the polar stereographic 
    %coordinates of overlapping profiles
    %check
    %figure(3)
    %plot(geoinfo.psX,geoinfo.psY,'b-o')
    %hold on
    %plot(geoinfo3.psX,geoinfo3.psY,'r-o')
    %plot(xi,yi,'g*')

    %round to closest intercept (only use longitude?)
    [geoinfoval,geoinfoidx]=min(abs(geoinfo.psX-xi));
    geoinfominVal=geoinfo.psX(geoinfoidx);

    [geoinfo3val,geoinfo3idx]=min(abs(geoinfo3.psX-xi));
    geoinfo3minVal=geoinfo3.psX(geoinfo3idx);

    geoinfo3layer1=geoinfo3.layer1(geoinfo3idx,2); %picked index (row below cut data) to move across to other trace
    dt=geoinfo3.time_range(2)-geoinfo3.time_range(1);%time step (for traces)

    geoinfo3.time_pick_abs=geoinfo3.traveltime_surface(geoinfo3idx)-geoinfo3.time_range(1);
    geoinfo3layer1_ind=geoinfo3layer1-(geoinfo3.time_pick_abs/dt); % gives 430 - 215 (surface pick)

    %geoinfo.time_range(geoinfo3layer1_ind)-geoinfo3.traveltime_surface(1);
    geoinfo.time_pick_abs=geoinfo.traveltime_surface(geoinfoidx)-geoinfo3.time_range(1);
    geoinfolayer1_ind=(geoinfo.time_pick_abs/dt)+geoinfo3layer1_ind;
    geoinfo.layer1=geoinfo.traveltime_surface*0;
    geoinfo.layer1(1,geoinfoidx)=geoinfolayer1_ind;

    plot(geoinfoidx,geoinfolayer1_ind,'b*', 'MarkerSize', 16)% this plots the overlapping point in this graph
end
%% Select starting point
% Make NaN matrix for 8 possible layers
if isfield(geoinfo,'layers')
    layers = geoinfo.layers;
    qualities = geoinfo.qualities;
else
    layers = NaN(8,nx);
    qualities = NaN(8,nx);
end

picks = cell(8, 1);

iteration = 1;
while selection_active
if iteration == 1
    layerplot = plot(1:length(layers),layers,'b-x',1:length(layers(cl,:)),layers(cl,:),'g-x');
    disp('Move and zoom if needed. Press enter to start picking.')
    pan on;
    pause() % you can zoom with your mouse and when your image is okay, you press any key
    pan off; % to escape the zoom mode
    
    disp('Pick the first point. Only the last click is saved, confirm pick with enter.')
    iteration = iteration + 1;
else
	disp('Pick next point. To move or zoom, press enter.')
end
[x,y,type]=ginput(); %gathers points until return

if ~selection_active
    break
end

if ~isempty(x)
    [x_in,y_in,type_in] = deal(round(x(end)),round(y(end)),type(end));
else
    [x_in,y_in,type_in] = deal(x,y,type);
end
layer = layers(cl,:);
quality = qualities(cl,:);
if type_in == 1
    picks{cl}(end+1,:) = [x_in, y_in]; % Add new picks to pick-cell

    isnewlayer = all(isnan(layer), 'all'); % Check if layer is empty (True/False).
    
    [layer,quality] = propagate_layer(layer,quality,geoinfo,window,x_in,y_in,leftright);
    if isnewlayer
        [layer,quality] = propagate_layer(layer,quality,geoinfo,window,x_in,y_in,-leftright);
    end
elseif type_in==3
    if leftright ==1
        layer(x_in+1:end) = NaN;
    else
        layer(1:x_in-1) = NaN;
    end
elseif isempty(type_in)
    disp('Move and zoom, to continue picking press enter.')
    pan on;
    pause() % you can zoom with your mouse and when your image is okay, you press any key
    pan off; % to escape the zoom mode
    continue
else
    disp('Input type unknown. Only pick with left and right mouse buttons.')
end

layers(cl,:) = layer;
qualities(cl,:) = quality;
% Plot updated layer
try
    delete(layerplot);
end
    layerplot = plot(1:length(layers),layers,'b-x',1:length(layers(cl,:)),layers(cl,:),'g-x');
end


%% save layer
geoinfo.num_layer = sum(max(~isnan(layers),[],2));
geoinfo.layers = layers;
geoinfo.qualities = qualities;
%geoinfo.layer1(geoinfoidx,2)=geoinfolayer1_ind; %still keep the overlapping point in the data

save(filename_geoinfo, 'geoinfo')