%to fix next
%optimize loop below
%how to start & stop a layer?
%automatically name layers by e.g. profile name and ind below surface pick
%(&maybe by polar x and y)
%automatically zoom into layer
%automatically adjust color bar - by setting the maximum a certain color in

clear all; 
close all;
addpath(append(pwd,'\auxfunctions'))

% Settings
input_section = '009'; % Current section to pick new layers.
cross_section = 'all'; % {'009'; '006'};  % Options : List of numbers (e.g.:{'009'; '006'}) or all files in data_folder('all'). Some already pick section to find cross-points.
raw_folder = '\raw_data';
raw_prefix = '\TopoallData_20190107_01_';
output_folder = '\picked layers';
output_prefix = '\LayerData_';
create_new_geoinfo = 0; % 1 = yes, 0 = no. CAUTION: Already picked layer for this echogram will be overwritten, if keep_old_picks = 0.
keep_old_picks = 1;     % 1 = yes, 0 = no
load_crossover = 1;     % 1 = yes, 0 = no
len_color_range = 100;
cmp = 'jet'; % e.g. 'jet', 'bone'

%TUNING PARAMETERS
tp.window=9; %vertical window, keep small to avoid jumping. Even numbers work as next odd number.
tp.seedthresh=5;% 5 seems to work ok, make bigger to have less, set 0 to take all (but then the line jumps automatically...)
%wavelet parameters
tp.wavelet = 'mexh';% choose the wavelet 'mexh' or 'morl' - Mexican Hat (mexh) gives cleaner results 
tp.maxwavelet=16; %min is always 3, layers size is half the wavelet scale
% decide how many pixels below bed layer is counted as background noise:
tp.bgSkip = 150; %default is 50 - makes a big difference for m-exh, higher is better
tp.MinBinForSurfacePick = 10;% when already preselected, this can be small
tp.smooth_sur=40; %between 30 and 60 seems to be good
%MinBinForBottomPick = 1500; %should be double-checked on first plot (as high as possible)
tp.MinBinForBottomPick = 1000; 
tp.smooth_bot=60; %smooth bottom pick, needs to be higher than surface pick, up to 200 ok
tp.RefHeight=600; %set the maximum height for topo correction of echogram, extended to 5000 since I got an error in some profiles
tp.rows=1000:5000; %cuts the radargram to limit processing (time) (top and bottom)
tp.clms=1:5000;
%%
filename_raw_data = append(pwd, raw_folder, raw_prefix, input_section, '.mat'); % Don't needed if geoinfofile already exists.
filename_geoinfo = append(pwd, output_folder, output_prefix, input_section, '.mat');
filenames_cross = {};
if strcmp(cross_section,'all')
    cross_struct = dir(append(pwd,output_folder,'\*.mat'));
    n_cross = length(cross_struct);
    for k = 1:n_cross
        filename_cross = append(cross_struct(k).folder, '\', cross_struct(k).name);
        filenames_cross = [filenames_cross; filename_cross];
    end
else
    n_cross = numel(cross_section);
    for k = 1:n_cross
        filename_cross = append(pwd,output_folder,output_prefix,cross_section{k},'.mat');
        filenames_cross = [filenames_cross; filename_cross];
    end
end
filenames_cross = setdiff(filenames_cross, {filename_geoinfo});
n_cross = length(filenames_cross);

[geoinfo, tp] = figure_tune(tp,filename_raw_data,filename_geoinfo,create_new_geoinfo,keep_old_picks);

ind = find(geoinfo.peakim);
[sy,sx]=ind2sub(size(geoinfo.peakim), ind);
nx = size(geoinfo.echogram,2);

dt=geoinfo.time_range(2)-geoinfo.time_range(1);%time step (for traces)
time_surface = geoinfo.traveltime_surface-geoinfo.time_range(1);
surface_ind = time_surface/dt;

dz = dt/2*1.68e8;
binshift = round((tp.RefHeight - geoinfo.elevation_surface)/dz);%this is essentially the surface reflector 
%%
db_echogram = mag2db(geoinfo.echogram);
f = figure(2); % of flat data with seed points
imagesc(db_echogram);
colormap(cmp)
hold on
plot(sx,sy,'r*', 'MarkerSize', 2) % plot seedpoints
set(gcf,'doublebuffer','on');
a = gca;
cr_half = len_color_range/2;

apos=get(a,'position');
set(a,'position',[apos(1) apos(2)+0.1 apos(3) apos(4)-0.1]);
bpos=[apos(1) apos(2)-0.05 apos(3)/3 0.05];
cpos=[apos(3)/3+0.15 apos(2)-0.05 0.12 0.05];
dpos=[apos(3)/3+0.28 apos(2)-0.05 0.12 0.05];
epos=[apos(3)/3+0.41 apos(2)-0.05 0.12 0.05];
fpos=[apos(3)/3+0.54 apos(2)-0.05 0.12 0.05];



cmin = round(min(db_echogram,[],'all')+cr_half); 
cmax = round(max(db_echogram,[],'all')-cr_half);
cini = min(cmax,-150);
set(a,'CLim',[cini-cr_half cini+cr_half]); % Initial color range

clear db_echogram
% Create color slider
S = "set(gca,'CLim',[get(gcbo,'value')-cr_half, get(gcbo,'value')+cr_half])";
ui_b = uicontrol('Parent',f,'Style','slider','Units','normalized','Position',bpos,...
              'value',cini,'min',cmin,'max',cmax,'callback',S); % Color slider. Atm it uses fixed max and min values, instead they could be adopted to the file values.
bgcolor = f.Color;
uicontrol('Parent',f,'Style','text','Units','normalized','Position',[bpos(1)-0.05,bpos(2),0.05,bpos(4)],...
                        'String',num2str(cmin),'BackgroundColor',bgcolor);
uicontrol('Parent',f,'Style','text','Units','normalized','Position',[bpos(1)+bpos(3)-0.05,bpos(2),0.05,bpos(4)],...
                'String',num2str(cmax),'BackgroundColor',bgcolor);
uicontrol('Parent',f,'Style','text','Units','normalized','Position',[bpos(1)+bpos(3)/2-0.15,bpos(2)-0.05,0.3,0.05],...
                'String',append('Color range (value ',char(177),' ',int2str(cr_half),')'),'BackgroundColor',bgcolor);

cl = 1; % Set number of current layers
S = "cl = get(gcbo,'value'); try set(layerplot(end),'YData',layers(cl,:)); end; try set(co_plot(end),'YData',cross_point_layers(cl,:)); end";
ui_c = uicontrol('Parent',f,'Style','popupmenu', 'String', {'Layer 1','Layer 2','Layer 3','Layer 4','Layer 5','Layer 6','Layer 7','Layer 8'},'Units','normalized','Position',cpos,...
              'value',cl,'callback',S); % Choose layer.
          
leftright = 1; % Go to left or right. lr = 1 -> right, lr = -1 -> left.
S = "leftright = get(gcbo,'value');";
ui_d = uicontrol('Parent',f,'Style','togglebutton', 'String', 'Go left','Units','normalized','Position',dpos,...
              'value',leftright,'min',1,'max',-1,'callback',S); % Select to go left or right.

S = "geoinfo.num_layer = sum(max(~isnan(layers),[],2)); geoinfo.layers = layers; geoinfo.layers_relto_surface = layers_relto_surface; geoinfo.layers_topo = layers_topo; geoinfo.layers_topo_depth = layers_topo_depth; geoinfo.qualities = qualities; geoinfo.tp = tp; save(filename_geoinfo, '-struct', 'geoinfo'); disp('Picks are saved.')";
ui_e = uicontrol('Parent',f,'Style','pushbutton', 'String', 'Save picks','Units','normalized','Position',epos,...
              'callback',S); % Finish selection
 
S = "set(ui_f, 'UserData', 0);";
ui_f = uicontrol('Parent',f,'Style','pushbutton', 'String', 'End picking','Units','normalized','Position',fpos,...
              'Callback',S,'UserData', 1); % Finish selection


%% Figure out cross-overs (load geoinfo3 in this case)
% need to load geoinfo3 manually 

cross_point_idx = NaN;
cross_point_layers = NaN(8,1);
if load_crossover
    for k = 1:n_cross
        geoinfo_co = load(filenames_cross{k}); % Loading the cross-over file
        if ~isfield(geoinfo_co,'psX') % Check if polar stereographic coordinates not exist in file
            [geoinfo_co.psX,geoinfo_co.psY] = ll2ps(geoinfo_co.latitude,geoinfo_co.longitude); %convert to polar stereographic
        end

        P = [geoinfo.psX; geoinfo.psY]';
        P_co= [geoinfo_co.psX; geoinfo_co.psY]';
        [points_dist,dist] = dsearchn(P,P_co);

        [val_dist, pos_dist] = min(dist);

        distthresh  = 10;  % Minimal allowed distance between cross- or neighbour-points.
        if val_dist < 10
            geoinfo_co_idx = pos_dist;
            geoinfo_idx = points_dist(pos_dist);
        end

        if exist('geoinfo_co_idx', 'var')
            %figure(3)
            %plot(P(:,1),P(:,2),'ko')
            %hold on
            %plot(P_co(:,1),P_co(:,2),'*g')
            %hold on
            %plot(P(geoinfo_idx,1),P(geoinfo_idx,2),'*r')
            %figure(2)
            if exist('geoinfo_co_idx', 'var')
                geoinfo_co_layers = geoinfo_co.layers(:,geoinfo_co_idx);
                dt=geoinfo_co.time_range(2)-geoinfo_co.time_range(1);%time step (for traces)

                geoinfo_co.time_pick_abs=geoinfo_co.traveltime_surface(geoinfo_co_idx)-geoinfo_co.time_range(1);
                geoinfo_co_layers_ind=geoinfo_co_layers-(geoinfo_co.time_pick_abs/dt); % gives 430 - 215 (surface pick)

                %geoinfo.time_range(geoinfo3layer1_ind)-geoinfo3.traveltime_surface(1);
                geoinfo.time_pick_abs=geoinfo.traveltime_surface(geoinfo_idx)-geoinfo_co.time_range(1);
                geoinfo_layers_ind=(geoinfo.time_pick_abs/dt)+geoinfo_co_layers_ind;
            end
            if any(cross_point_layers)
                cross_point_idx = [cross_point_idx, geoinfo_idx];
                cross_point_layers = [cross_point_layers, geoinfo_layers_ind];
            elseif exist('geoinfo_layers_ind', 'var')
                cross_point_idx = geoinfo_idx;
                cross_point_layers = geoinfo_layers_ind;
            end 
            clear geoinfo_co_layers_ind geoinfo_layers_ind geoinfo_co_idx geoinfo_idx
        end
    end
end

co_plot = plot(cross_point_idx,cross_point_layers,'k*', cross_point_idx, cross_point_layers(cl,:),'b*', 'MarkerSize', 16);% this plots the overlapping point in this graph

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

while get(ui_f, 'UserData')
if iteration == 1
    layerplot = plot(1:length(layers),layers,'k-x',1:length(layers(cl,:)),layers(cl,:),'b-x');
    disp('Move and zoom if needed. Press enter to start picking.')
    pan on;
    pause(); % you can zoom with your mouse and when your image is okay, you press any key
    pan off; % to escape the zoom mode
    if ~get(ui_f, 'UserData')
        break
    end
    disp('Pick the first point. Only the last click is saved, confirm pick with enter.')
    iteration = iteration + 1;
else
	disp('Pick next point. To move or zoom, press enter.')
end

[x,y,type]=ginput(); %gathers points until return

if ~get(ui_f, 'UserData')
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
    
    [layer,quality] = propagate_layer(layer,quality,geoinfo,tp.window,x_in,y_in,leftright);
    if isnewlayer
        [layer,quality] = propagate_layer(layer,quality,geoinfo,tp.window,x_in,y_in,-leftright);
    end
elseif type_in==3
    if leftright ==1
        layer(x_in+1:end) = NaN;
    else
        layer(1:x_in-1) = NaN;
    end
elseif isempty(type_in)
    disp('Move and zoom. To continue picking, press enter.')
    pan on;
    pause() % you can zoom with your mouse and when your image is okay, you press any key
    pan off; % to escape the zoom mode
    if ~get(ui_f, 'UserData')
        break
    end
else
    disp('Input type unknown. Only pick with left and right mouse buttons.')
end

layers(cl,:) = layer;
qualities(cl,:) = quality;
layers_relto_surface = layers - surface_ind;
layers_topo = layers_relto_surface + binshift;
layers_topo_depth = tp.RefHeight - layers_topo * dz;
% Plot updated layer
try
    delete(layerplot);
end
    layerplot = plot(1:length(layers),layers,'k-x',1:length(layers(cl,:)),layers(cl,:),'b-x');
end
disp('Picking finished. Picked layers are saved.')


%% save layer
layers_relto_surface = layers - surface_ind;
layers_topo = layers_relto_surface + binshift;
layers_topo_depth = tp.RefHeight - layers_topo * dz;

geoinfo.num_layer = sum(max(~isnan(layers),[],2));
geoinfo.layers = layers;
geoinfo.layers_relto_surface = layers_relto_surface;
geoinfo.layers_topo = layers_topo;
geoinfo.layers_topo_depth = layers_topo_depth;
geoinfo.qualities = qualities;
geoinfo.tp = tp;
%geoinfo.layer1(geoinfoidx,2)=geoinfolayer1_ind; %still keep the overlapping point in the data
save(filename_geoinfo, '-struct', 'geoinfo')
