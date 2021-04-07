function varargout = snobfitguiUV(varargin)
% snobfitguiUV M-file for snobfitguiUV.fig
%      snobfitguiUV, by itself, creates a new snobfitguiUV or raises the existing
%      singleton*.
%
%      H = snobfitguiUV returns the handle to a new snobfitguiUV or the handle to
%      the existing singleton*.
%
%      snobfitguiUV('CALLBACK', hObject, eventData, handles,...) calls the local
%      function named CALLBACK in snobfitguiUV.M with the given input arguments.
%
%      snobfitguiUV('Property', 'Value',...) creates a new snobfitguiUV or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before snobfitgui_OpeningFunction gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to snobfitguiextract_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help snobfitguiUV

% Last Modified by GUIDE v2.5 06-Sep-2019 13:29:08

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @snobfitguiUV_OpeningFcn, ...
    'gui_OutputFcn',  @snobfitguiUV_OutputFcn, ...
    'gui_LayoutFcn',  [] , ...
    'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT

%------------------------------------------------------------------------%
% There are 4 key functions which make up the snobfitguiUV code:

% 1. Start_Callback is trigggered after the start button is pressed this
% sees which objects are enabled and if the user wants to optimiese them, 
% asks the user to select direcory containing GC files, initalises timer 
% functions then starts the snobfitTimecallback timer (2) function. 

% 2. snobfitTimecallback calls the response grab function and sets the next
% set of reaction conditions, then triggers the tempstabletimcallback (3). 

% 3. tempstabletimcallback holds the snobfit code until the reactor
% conditions are stable, the reactor has reached steady state. Once these
% conditions are met the gcfiletimcallback (4) is triggered. 

% 4. gcfiletimcallback determines whether enough time has elapsed for the 
% gc/hplc to be ready to recive a new sample then triggers the sample loop 
% starting the next HPLC/GC run, the snobfitTimecallback (2) is then 
% triggered and the cycle continous until the maximun set number of 
% experiments has been reached. 

%------------------------------------------------------------------------%

% --- Executes just before snobfitguiUV is made visible.
function snobfitguiUV_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure

% varargin   command line arguments to snobfitguiUV (see VARARGIN)
 
%===============================Actual Code Starts Below============

% input arguments are in the form snobfitguiUV(connectedObjects, parent),
% where connectedObjects is a logical vector of the objects connected in
% the main gui and parent is the handle to the main CO2 GUI so that appdata
% can be fetched from it


if ~(nargin == 5)
    error('Incorrect number of input arguments')
elseif ~isnumeric(varargin{1}) || iscell(varargin{1}) ||...
        any(size(varargin{1}) ~= [8, 1]) ||...
        any(varargin{1} ~= round(varargin{1})) ||...
        any(varargin{1} < 0) || any(varargin{1} > 1)
    error('connectedObjects must be a 8x1 (column) vector of logical values (1s and 0s)')
elseif ~ishandle(varargin{2})
    error('Must Be A Valide Handle to the main CO2 GUI')
else
    % stashes away the data
    handles.connectedObjects = varargin{1};
    handles.MainGUI = varargin{2};
end
%get serial object info from main CO2 GUI
objectConfig=getappdata(handles.MainGUI,'objectConfig'); 
objectTypes=getappdata(handles.MainGUI,'objectTypes');
%get the serial object names from this
names = {objectConfig.name}; 

%set empty value for linked objects
setappdata(hObject,'linked',zeros(8,8));

%startup for GC options
GCcounter = 1;
GCoptions = {};

% sets up the check boxes with the correct values, then runs the
% enableCallbacks to correctly enable the right fields
for m = 1:8
    % defines handle
    checkbox = sprintf('checkbox%d', m);
    dev = sprintf('dev%d', m);
    noise = sprintf('noise%d', m);
    quench = sprintf('quench%d', m);
    rest = sprintf('rest%d', m);


    %get the type of object from the config setting
    type = objectConfig(m).type;

    %get some details from the type
    defaultdev = objectTypes(type).allowedDeviation;
    defaultnoise = objectTypes(type).allowedNoise;
    class = objectTypes(type).class;

    setappdata(hObject,dev,defaultdev);
    setappdata(hObject,noise,defaultnoise);
    
    % sets the value
    set(handles.(checkbox), 'Value', handles.connectedObjects(m))

    % if it's not connected, disable the box
    if ~handles.connectedObjects(m)
        set(handles.(checkbox), 'Enable', 'Off')
    end


    %check if object is a sampleloop (can't optimise but might want to ues)
    if strcmp(class, 'loop')
        set(handles.(checkbox), 'Enable', 'Off')
        set(handles.(checkbox), 'Value', 0)

        %if also connected
        if handles.connectedObjects(m)
            %save name and number of serial object for use later
            GCoptions{GCcounter} = sprintf('Serial Object %d-%s',m,names{m});
            GCserialNumber(GCcounter,1) = m;
            %increase count
            GCcounter = GCcounter + 1;
        end
    end

    nametag = sprintf('name%d', m); %define handle for name field to change
    set(handles.(nametag),'String',names{m});

    % runs the update fields callback so it looks like it has been
    % triggered by the checkbox itself
    enableCallback(handles.(checkbox), eventdata, handles)
end

%test if anything has been added to GCoptions
if ~isempty(GCoptions)
    %set list
    set(handles.GCselect,'String',GCoptions)
%     set(handles.GCselect2,'String',GCoptions)
    %store the serialNumbers for later use
    handles.GCserialNumber = GCserialNumber;
else
    %show message in box and disable it and the corresponding checkbox
    set(handles.GCselect,'String','No Connected Sample Loops')
    set(handles.GCselect,'Enable','Off')
    set(handles.altGCcheck,'Enable','Off')
%     set(handles.GCselect2,'String','No Connected Sample Loops')
%     set(handles.GCselect2,'Enable','Off')
    
end
%set the default GC option (the task kill method)
handles.GCoption = 0;

%set the default target option (yield optimsiation)
handles.target = 1;

% Choose default command line output for snobfitguiUV
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% --- Executes on button press in start.
function start_Callback(hObject, eventdata, handles)

button = get(hObject,'Value'); %is this a button down or button up

if button==1 %if button down

    %attempt to fetch all the required data and calculations
    try              
        %work out which objects are actually enabled and are actually going
        %to be optimised (this can't be changed by user later!)
        
        handles.NiPhPump = pumpobj(6)
        fopen(handles.NiPhPump)

        
        %assume everything is enabled 
        enabledObjectNumbers = true(1,8);
        %assume everything is optimised 
        optimiseObjectNumbers = true(1, 8);
        %assume all included in ResT
        restObjectNumbers = true(1, 8);
        
        %get the linked matrix
        linked = getappdata(handles.snobfitgui, 'linked');        
        %check each object
        for obj = 1:8
            %work out if still needs checking
            if optimiseObjectNumbers(1, obj)
                %work out if enabled by user
                if get(handles.(sprintf('checkbox%d', obj)), 'Value')
                    %if so then need to check for links in that object
                    optimiseObjectNumbers(1, linked(obj, :) == 1) = false;
                else
                    %if not then need to turn off in both lists
                    enabledObjectNumbers(1, obj) = false;
                    optimiseObjectNumbers(1, obj) = false;
                end                
            end
            %do nothing if already turned off
        end
        
        
        for obj = 1:8
            %work out if still needs checking
            if restObjectNumbers(1, obj)
                %work out if enabled by user
                if get(handles.(sprintf('rest%d', obj)), 'Value')
                    %if so then need to check for links in that object
                    restObjectNumbers(1, linked(obj, :) == 1) = false;
                else
                    %if not then need to turn off in both lists
                    restObjectNumbers(1, obj) = false;
                end                
            end
            %do nothing if already turned off
        end 
        
        %convert into list of numbers instead of true/false and store in
        %the handles structure
        handles.optimiseObjectNumbers = find(optimiseObjectNumbers);
        handles.enabledObjectNumbers = find(enabledObjectNumbers);
        handles.restObjectNumbers = find(restObjectNumbers);
        %update the handles structure
        guidata(hObject, handles);
        
        %get the parts which could be changed by the user after starting
        %the optimisation
        settings = getDetails(hObject, eventdata, handles);
        
        %ask user where the gc file & log will be saved
        filepath = uigetdir('C:\',...
            'Select main directory for log files');
        
        filepathUV = uigetdir('C:\NIR-Experimental',...
            'Select main directory where UV data is stored');
        %check that a selection was made
% %  RICH REMOVED 2308       if isequal(filepath,0) %check that a file was selected
% %             error('no file selected')
% %         end
        handles.path = filepath;
        handles.pathUV = filepathUV;
        %make full paths for the files
        %gc file
        %handles.gcfile = fullfile(filepath, 'GC-ASCII-FILE.txt');
        %standard log file
        handles.logfile = fullfile(filepath, sprintf('Snobfit-%s.txt',...
            datestr(clock, 'dd-mm-yyyy_HH-MM-SS')));
        %NEW 21112013
        handles.logfile2 = fullfile(filepath, sprintf('SnobfitUserData-%s.mat',...
            datestr(clock, 'dd-mm-yyyy_HH-MM-SS')));
        
        handles.logfile3 = fullfile(filepath, sprintf('SnobfitLogData-%s.txt',...
            datestr(clock, 'dd-mm-yyyy_HH-MM-SS')));
        
        %open log file and discard any contents
        fid = fopen(handles.logfile,'w+');
        
        %get the object config and object types from main GUI (needed to
        %figure out logging) - also need field order
        objectConfigs = getappdata(handles.MainGUI, 'objectConfig');
        objectTypes = getappdata(handles.MainGUI, 'objectTypes');
        fieldorder =...
            {'currentTemp', 'setTemp', 'currentPress', 'setPress', 'flow'};
        
        %preallocate set fields and actual fields
        handles.setFields = zeros(size(enabledObjectNumbers));
        handles.actFields = zeros(size(enabledObjectNumbers));
        %start header row for log file; format of log file will be:
        %[timeset simplexNO vertexNO] [calccondition setcondition
        %actcondition] for each object followed by [gctime gcname gcyield
        %response] followed by [pico channels] - note: time is in serial
        %time format
        
        % add the [timeset simplexNO vertexNO] headings
        header = 'timeset,simplexNo,vertexNo';
        
        %loop through each object to add the [calccondition setcondition
        %actcondition] headings and also store stuff about which fields to
        %read for later use
        sortobject = 1;
        for obj = 1:size(handles.enabledObjectNumbers, 2)
            %find number for object
            objectNumber = handles.enabledObjectNumbers(obj);
            %find the name of the object
            nameStr = objectConfigs(objectNumber).name;
            %find the type for this object
            objectType = objectConfigs(objectNumber).type;
            %find the main field for this object            
            objectField = objectTypes(objectType).mainField;
            if strcmp(objectField,'currentTemp');
                sortobject = obj;
            end
            %find that field within the field order
            objectField = find(strcmp(fieldorder, objectField));
            %find the position in serialdata for the field of interest
            %(first column is time followed by 5 columns for each object)            
            handles.actFields(obj)=(objectNumber-1) * 5 + objectField + 1;
            % EDIT to allow for MFC (MUST BE OBJECT 8)
            if objectType == 31 % MFC
                handles.actFields(obj)=40;
            end
            %test if the flow field
            if objectField == 5
                %if is then there is no separate set field
                handles.setFields(obj)=handles.actFields(obj);
            else
                %if not then the next field is the set field
                handles.setFields(obj)=handles.actFields(obj) + 1;
            end
            %extend the header
            header = sprintf('%s,%s-Calc,%s-Set,%s-Act', header,...
                nameStr,nameStr,nameStr);
        end
        
        %add the [gctime gcname gcyield response] headings
        header = sprintf('%s,%s', header,...
            'gcTime,gcName,gcYield,Response');
        
        %add the [picoChannels] headings
        %get the picoConfig
        picoConfigs = getappdata(handles.MainGUI,'tc08Config');
        %loop through the first 8 channels and add name to header
        for channel = 1:8
            header = sprintf('%s,%s', header,picoConfigs(channel).name);
        end
        %write this to the file
        fprintf(fid, '%s\n', header);
        fclose(fid);
%         %open the GC file & discard contents
%         fid = fopen(handles.gcfile,'w+');
%         fclose(fid);
        %change the button text
        set(handles.start, 'String', 'Stop')
        
        %store linked status  
        
        
        handles.linked = getappdata(handles.snobfitgui, 'linked');
        linkedmat=zeros(8,8);
        for m = 1:8
        
                        linkhandle = sprintf('FRobj%d',(m));
                        link=str2num(eval(strcat('get(handles.',linkhandle,',''String'')')));
                        FRhandle = sprintf('flowratio%d',(m));
                        FRlink=str2num(eval(strcat('get(handles.',FRhandle,',''String'')')));
                        if link>=1
                            linkedmat(link,m)=FRlink
                        end
                        setappdata(handles.snobfitgui,'linked',linkedmat)
        end
        
        handles.linked = getappdata(handles.snobfitgui, 'linked');
        
        %create params structure for snobfit
        handles.params = struct('bounds',{[settings.minBounds],[settings.maxBounds]}...
            ,'nreq',settings.nreq,'p',settings.prob)
        handles.file = strcat(filepath,'\snobfilev1.mat')
        
        %setup timerdata for snobfit timer
        snobfit_data = struct('conditions',zeros(1,1),'snob_count',1,'response',...
            zeros(settings.nreq,1),'cycle',1,'stableTime',[],'startTime',[],'measurement_number',0,'gc_identity',[],'sortobject',sortobject);
        % to snobfit
        
             %REINSTATE NEXT TIME
             set(handles.conditionsText,'String','')
             if exist (handles.file,'file')
                 choice = questdlg('File already exists, continue previous optimisation from last completed set?', ...
                     'Yes','No');
                 % Handle response
                 switch choice
                     case 'Yes'
                         load(handles.file,'request');
                         conditions=request
                         load(handles.file,'f');
                         load(handles.file,'x')
                         condtext1=horzcat(x,-f(:,1));
                         set(handles.conditionsText,'String',num2str(condtext1))
                     case 'No'
                         %[conditions,xbest,fbest] = snobfit(handles.file,x,f,handles.params,[settings.dxValues]);
                         
                          [conditions,xbest,fbest] = snobfit(handles.file,[],[],handles.params,[settings.dxValues]);
                         %[conditions,xbest,fbest] = snobfit(handles.file,x,f,handles.params,[settings.dxValues]);
                         %replace [] with x and f or snobfit_data.conditions and f if you want to load existing data into a snobfit 
                                      end
             else
                             %[conditions,xbest,fbest] = snobfit(handles.file,[],[],handles.params,[settings.dxValues]);
                             
                             [conditions,xbest,fbest] = snobfit(handles.file,[],[],handles.params,[settings.dxValues])
                             
             end
          %REMOVED TEMPERATURE SORTING FOR EXPERIMENT 20052014   
       
         
          
          [conditions]=sortrows(conditions,snobfit_data.sortobject)
       
        snobfit_data.conditions = conditions(:,1:end-2)
        snobfit_data.conditions3 = conditions(:,1:end-2)
        snobfit_data.conditions4 = conditions(:,1:end) %for gui display box
        
        NaBH4_conc = conditions(:,1)
        AuNP_conc = conditions(:,2)
        Residence_time = conditions(:,3)

        [new2conditions] = conditions_gen(NaBH4_conc,AuNP_conc,Residence_time)
         
         conditions(:,1) = new2conditions(:,1)
         conditions(:,2) = new2conditions(:,2)
         conditions(:,3) = new2conditions(:,3)
%         
         snobfit_data.conditions2 = new2conditions 
%    
       
    if get(handles.DOEbox,'Value')==1
        [file,path]=uigetfile('.mat','Select mat file containing [conditions] array, columns should match optimised objects in SNOBFIT gui');
        file=strcat(path,file);
        conditions=load(file,'conditions');
        %structured array
        conditions=conditions.conditions;
        [conditions]=horzcat(conditions,NaN(size(conditions,1),2));
    end
        oldconditions=get(handles.conditionsText,'String');  

        newconditions=num2str(snobfit_data.conditions4);
    combinedconds=strvcat(oldconditions,newconditions);
    set(handles.conditionsText,'String',combinedconds)% (gnc) print conditions to snobfit gui
        
        %set(handles.conditionsText,'String',num2str(conditions))
        %send conditions to snobfitdata
       
        
        snobfit_data.conditions(1:size(conditions,1),1:size(conditions,2)-2) = conditions(:,1:size(conditions,2)-2); %generates an extra 2 colums, one for the estimate and one for the actual response. 
        snobfit_data.act_conds=zeros(size(conditions));
        
            
        
        %time4
        %setup snobfit timer (main timer)
        snobfittim = timer('TimerFcn', {@snobfitTimcallback, handles},...
            'ExecutionMode','singleShot', 'Tag', 'snobfit_tim',...
            'UserData', snobfit_data, 'ObjectVisibility', 'off',...
            'TasksToExecute', inf, 'Name', 'snobfittimer');
        %snobfit gc assumed to be running at beginning, enables time for
        %analysis to complete
        snobfit_data.gc_identity=now;
        snobfit_data.cycle=1;
        snobfit_data.measurement_number=1;
        set(timerfindall('Tag','snobfit_tim'),'UserData',snobfit_data)
        
        %setup stable check timer
        stabletim = timer('Period', 12, 'TasksToExecute', inf,...
            'TimerFcn', {@stabletimcallback, handles}, 'ExecutionMode',...
            'fixedSpacing', 'Tag', 'stabletest', 'StartDelay', 10,...
            'StartFcn', {@stablestartcallback, handles},...
            'ObjectVisibility', 'off', 'Name', 'stabletimer');
         
        tempstabletim = timer('Period', 13, 'TasksToExecute', inf,...
            'TimerFcn', {@tempstabletimcallback, handles}, 'ExecutionMode',...
            'fixedSpacing', 'Tag', 'tempstabletest', 'StartDelay', 10,...
            'StartFcn', {@stablestartcallback, handles},...
            'ObjectVisibility', 'off', 'Name', 'tempstabletimer');
        
        %setup gc file check timer
        gcfiletim = timer('Period', 19, 'TasksToExecute', inf,...
            'TimerFcn', {@gcfiletimcallback, handles}, 'ExecutionMode',...
            'fixedSpacing', 'Tag', 'GCfiletimer', 'ObjectVisibility', 'off', 'UserData',...
            struct, 'Name', 'gcfiletimer');       

        %setup pause check timer
        pausetim = timer('Period', 21, 'TasksToExecute', inf,...
            'TimerFcn', {@pausetimcallback, handles}, 'ExecutionMode',...
            'fixedSpacing', 'Tag','pausetimc', 'StartDelay',...
            10, 'ObjectVisibility', 'off', 'UserData',...
            struct, 'Name', 'pausetimer'); 
              
        %start the experiment!
     
        FRNiPhPump = (((((conditions(1,1)+(conditions(1,2)+(conditions(1,3))))*0.1)))) %sets flow rate of pump 1 as a difined ratio of pumps 2,3 and 4.

        pumpobjwriteflow(handles.NiPhPump, FRNiPhPump)
        
        start(snobfittim) 

    catch
        errmsg = lasterror; %get the error stucture which might have been generated above
        errmsg = errmsg.message; %get message from struture
        endFirstLine = regexp(errmsg, '[\n\r]'); %find where the first line ends
        errmsg = errmsg((endFirstLine+1):end); %remove first line from message
        errordlg(errmsg) %display error box for user to see
        set(handles.start,'Value',0,'String','Start') %change the toggle box back to up as the function did not start
    end
else %if button down

    %ask user if they really want to stop
    userans = questdlg('Really Stop SNOBFIT Operation?', 'STOP?',...
        'Yes', 'No', 'No');

    if strcmp(userans,'Yes') %user selects yes

        %get timers
        snobfitTimer = timerfindall('Tag','snobfit_tim');
        BPRchangetimer = timerfindall('Tag','BPRPchange');
        GCfiletimer = timerfindall('Tag','GCfiletimer');
        restarttimer = timerfindall('Tag','restarttimer');
        pausetimer = timerfindall('Tag','pausetimc')
        tempstabletimer = timerfindall('Tag','tempstabletest')
        
        if ~isempty(pausetimer) %if there is any timers with this tag
            stop(pausetimer) %stop timer
            delete(pausetimer) %delete timer
        end
        clear('pausetimer') %delete pointer to timer
        
        if ~isempty(tempstabletimer) %if there is any timers with this tag
            stop(tempstabletimer) %stop timer
            delete(tempstabletimer) %delete timer
        end
        clear('tempstabletimer') %delete pointer to timer
        
        if ~isempty(snobfitTimer) %if there is any timers with this tag
            stop(snobfitTimer) %stop timer
            delete(snobfitTimer) %delete timer
        end
        clear('snobfitTimer') %delete pointer to timer

        if ~isempty(stabletimer) %if there is any timers with this tag
            stop(stabletimer) %stop timer 
            delete(stabletimer) %delete timer
        end
        clear('stabletimer') %delete pointer to timer
        
        if ~isempty(stabletest) %if there is any timers with this tag
            stop(stabletest) %stop timer 
            delete(stabletest) %delete timer
        end
        clear('stabletest') %delete pointer to timer
        
        if ~isempty(BPRchangetimer) %if there is any timers with this tag
            stop(BPRchangetimer) %stop timer
            delete(BPRchangetimer) %delete timer
        end
        clear('BPRchangetimer') %delete pointer to timer

        if ~isempty(GCfiletimer) %if there is any timers with this tag
            stop(GCfiletimer) %stop timer
            delete(GCfiletimer) %delete timer
        end
        clear('GCfiletimer') %delete pointer to timer

        if ~isempty(restarttimer) %if there is any timers with this tag
            stop(restarttimer) %stop timer
            delete(restarttimer) %delete timer
        end
        clear('COVtimer') %delete pointer to timer
        
        %disable view button
        set(handles.viewButton, 'Visible', 'Off', 'Enable', 'Off')

        %change the toggle button back to original condition
        set(handles.start,'String','Start')
        set(handles.status1,'String','Stopped') %change the status box
        set(handles.status2,'String','Stopped') %change status box

    else %user does not select yes
        set(handles.start,'Value',1) %change the toggle button back to down as function not really stopped
    end
end
guidata(hObject, handles);

% --- Executes after HPLC/GC/UV-vis run retrives and sets new conditions.        
function snobfitTimcallback(obj, event, handles)
%get the snobfit data
snobfit_data = get(obj, 'UserData');
%is the cycle (which determines where you are in the conditions list)
%greater than the number of conditions (meaning that tstahe list has been
%completed)
if snobfit_data.cycle > size(snobfit_data.conditions,1)
    %snobfit_data.log(snobfit_data.snob_count).conditions=snobfit_data.conditions
    params = handles.params;
    path = handles.path;
     
    % start the response grab function HERE
    snobfit_data.response = RGF(snobfit_data, params,path,handles);
    
    
    
    %preallocate f and put the responses into it
     f = zeros(size(snobfit_data.response,1),2)
     f(:,1) = snobfit_data.response
     
    %EDIT FOR COST OPT
    [conditions,xbest,fbest] = snobfit(handles.file,snobfit_data.conditions3...
       ,-f,handles.params);
   
    snobfit_data.log(snobfit_data.snob_count).conditions=conditions 
    snobfitdata = get(obj,'UserData');
    %save the data
    save(handles.logfile2,'snobfitdata')

    [conditions]=sortrows(conditions,snobfit_data.sortobject);
    
        snobfit_data.conditions = conditions(:,1:end-2) %for everything else 
        snobfit_data.conditions3 = conditions(:,1:end-2) %for snobfit optimisation
        snobfit_data.conditions4 = conditions(:,1:end) %for gui display box
       
        NaBH4_conc = conditions(:,1)
        AuNP_conc = conditions(:,2)
        Residence_time = conditions(:,3)
        
        [new2conditions] = conditions_gen(NaBH4_conc,AuNP_conc,Residence_time)
        snobfit_data.conditions2 = new2conditions
        
        conditions(:,1) = new2conditions(:,1)
        conditions(:,2) = new2conditions(:,2)
        conditions(:,3) = new2conditions(:,3)
        
          
    
        
        
%[conditions]=sortrows(conditions,snobfit_data.sortobject)

    oldconditions=get(handles.conditionsText,'String');
    f2=f(:,1)
    results=num2str(f2');
    newconditions=num2str(snobfit_data.conditions4);
    combinedconds=strvcat(oldconditions,results,newconditions);
    set(handles.conditionsText,'String',combinedconds)
    %update the snobfitTim userdata for the next runs
    snobfit_data.conditions=[]
    snobfit_data.conditions(1:size(conditions,1),1:size(conditions,2)-2) = conditions(:,1:size(conditions,2)-2); 
    snobfit_data.act_conds=zeros(size(conditions));
    snobfit_data.snob_count = snobfit_data.snob_count + 1;
    snobfit_data.cycle = 1; 
       
        %auto stop after 15 calls! FIND THE OTHER INSTANCE OF THIS!
maxIterations = str2double(get(handles.iterationsBox, 'String'));        
     if snobfit_data.snob_count > maxIterations
        conditions =zeros(size(conditions));
        snobfit_data.conditions=conditions;
     end
end

%update status fields
set(handles.status1, 'String',  sprintf...
    ('Experiment No.%d', snobfit_data.measurement_number))
set(handles.status2, 'String', 'Setting Conditions')
snobfit_data.startTime = now;
%pump 2 is set as ratio of pump 1
% ratio=get(handles.ratiobox,'Value');
% ratio2=get(handles.ratiobox2,'Value');
% if ratio==0
    
%     try
        %in try catch loop due to communication errors with tempcontrollers
        setCondition(handles, snobfit_data.conditions2(snobfit_data.cycle,:))
%     catch
%         pause(3)
%         setCondition(handles, snobfit_data.conditions(snobfit_data.cycle,:))
%     end
% else
%     snobfitsetcond=snobfit_data.conditions;
%     snobfitsetcond(snobfit_data.cycle,3)=snobfit_data.conditions(snobfit_data.cycle,1)*snobfit_data.conditions(snobfit_data.cycle,3)
%     setCondition(handles, snobfitsetcond(snobfit_data.cycle,:))
% end

%code added to save the text box as text filelog 250117

oldconditions=get(handles.conditionsText,'String');
 CellArray = strcat(oldconditions); 
    fid = fopen(handles.logfile3,'w');
    for r=1:size(CellArray,1)
        fprintf(fid,'%s\n',CellArray(r,:));
    end
    fclose(fid);
   
%update the user data
set(obj,'UserData',snobfit_data)
%start the stable test timer
c = fix(clock);
set(handles.status3, 'String', 'Temperature Stability started at:')
set(handles.status4,'string', sprintf(datestr(c)));

start(timerfindall('Tag', 'tempstabletest'))
      
function tempstabletimcallback(obj, event, handles)
                
                
                %get the handle to the main CO2 gui
                MainGUI = handles.MainGUI;
                %get the handle to the optimise gui
                snobfitgui = handles.snobfitgui;
                %standard field structure in the main GUI
                fieldorder = {'currentTemp', 'setTemp', 'currentPress', 'setPress',...
                    'flow'};
                set(handles.status2, 'String', 'Checking Temperature and Pressure at:')
                %set clock for steady state waiting time
                c = fix(clock);
                %set waiting time
                set(handles.waiting_time,'string', sprintf(datestr(c)));
                
                %get the objects details from from the main GUI
                objectconfig = getappdata(MainGUI, 'objectConfig');
                objecttype = getappdata(MainGUI, 'objectTypes');
                
                %get the current array for check objects
                checkobject = get(obj, 'UserData');
                % get the object numbers from handles structure
                objectNumbers = handles.enabledObjectNumbers;
                %get the current poisition in data
                currenttick = getappdata(MainGUI, 'serialDataTicker');
                Data = getappdata(MainGUI, 'serialData');
                %pico data
                picoData = getappdata(MainGUI, 'picoData');
                
                
                
                currenttime = Data(currenttick - 1, 1);
                
                %overwrite so that only the last 1! mins are present in the data
                
                
                %get the gctimer data
                snobfit_data = get(timerfindall('Tag','snobfit_tim'),'UserData');

                allConditions = deLinkConds(handles, snobfit_data.conditions2(snobfit_data.cycle,1:end));
                
                tempconditions=snobfit_data.conditions2(snobfit_data.cycle,1:end);
                
                for m = 1:size(objectNumbers, 2)
                    Data = Data(Data(:, 1) >= currenttime - ((30000/60) / (60 * 24)), :);
                    objectNumber = objectNumbers(m);
                    type = objectconfig(objectNumber).type;
                    currentfield = objecttype(type).mainField;
                    %find where in the data this object is
                    currentfield = handles.actFields(1, m);
                    setfield = handles.setFields(1, m);
                    %get the handles to the dev and noise data
                    devHandle = sprintf('dev%d', objectNumber);
                    noiseHandle = sprintf('noise%d', objectNumber);
                    quenchhandle = sprintf('quench%d', objectNumber);
                    restHandle=sprintf('rest%d', objectNumber);
                    %get the allowed deviation and noise for this object
                    allowedDeviation = getappdata(snobfitgui, devHandle);
                    allowedNoise = getappdata(snobfitgui, noiseHandle);
                    quench=str2num(eval(strcat('get(handles.',quenchhandle,',''String'')')));
                    rest=eval(strcat('get(handles.',restHandle,',''Value'')'));
                    %get the last entry in the data for this object
                    currentvalue = Data(end,currentfield);
                    currentset = Data(end,setfield);
                    %get class of object, useful if special rules - see below
                    class = objecttype(type).class;
                    %get condition for this object
                    condition = allConditions(1,m);
                    %COMMON EDIT
                    if strcmp(class, 'pump')

                    tempconditions(m)=quench;
                    
                    end
                end
                
                try
                    %in try catch loop due to communication errors with tempcontrollers
                    setCondition(handles, tempconditions)
                catch
                    pause(3)
                    setCondition(handles, tempconditions)
                end
                
                %NEW STUFF FOR VARIABLE STEADY STATE
                %totalflowrate=10;
                
                
                %COMMON EDIT
                
                waittime=0.1;
                
                %time in mins to wait for temp equilibration before pumping
                steadyStateTime=str2num(get(handles.steadyStateTimeBox,'String'));
                    reactorvolume=str2num(get(handles.reactorvolumetextbox,'String'));
                    
                totalflowrate=20;
                
                
                for m = 1:size(objectNumbers, 2)
                    %check the class of object
                    %TIDY THIS UP LOTS OF FIELDS NOT USED
                    Data = Data(Data(:, 1) >= currenttime - ((30000/60) / (60 * 24)), :);
                    objectNumber = objectNumbers(m);
                    type = objectconfig(objectNumber).type;
                    currentfield = objecttype(type).mainField;
                    %find where in the data this object is
                    currentfield = handles.actFields(1, m);
                    setfield = handles.setFields(1, m);
                    %get the handles to the dev and noise data
                    devHandle = sprintf('dev%d', objectNumber);
                    noiseHandle = sprintf('noise%d', objectNumber);
                    %get the allowed deviation and noise for this object
                    allowedDeviation = getappdata(snobfitgui, devHandle);
                    allowedNoise = getappdata(snobfitgui, noiseHandle);
                    %get the last entry in the data for this object
                    currentvalue = Data(end,currentfield);
                    currentset = Data(end,setfield);
                    %get class of object, useful if special rules - see below
                    class = objecttype(type).class;
                    %get condition for this object
                    condition = allConditions(1,m);
                    if strcmp(class, 'pump')
                        checkobject(m) = 0;
                    end
                end
                
                pausetest=get(handles.pauseopt,'Value');
                if pausetest==0;
                    
                    
                    
                    steadyStateTime=str2num(get(handles.steadyStateTimeBox,'String'));
                    reactorvolume=str2num(get(handles.reactorvolumetextbox,'String'));
                    %add this as a GUI object - DONE
                    startdelayHPLC=(reactorvolume/(totalflowrate))*60*steadyStateTime;
                    startdelayHPLC=round(startdelayHPLC);
                    set(handles.hplcstartdelaytext,'string',num2str(startdelayHPLC));
                    %NEW STUFF FOR VARIABLE STEADY STATE
                    
                    Data = Data(Data(:, 1) >= currenttime - ((startdelayHPLC/60) / (60 * 24)), :);
                    picoData=picoData(picoData(:, 1) >= currenttime - ((startdelayHPLC/60) / (60 * 24)), :);
                    
                    for m = 1:size(objectNumbers, 2)
                        
                        %get data for kit
                        
                        objectNumber = objectNumbers(m);
                        type = objectconfig(objectNumber).type;
                        currentfield = objecttype(type).mainField;
                        %find where in the data this object is
                        currentfield = handles.actFields(1, m);
                        setfield = handles.setFields(1, m);
                        %get the handles to the dev and noise data
                        devHandle = sprintf('dev%d', objectNumber);
                        noiseHandle = sprintf('noise%d', objectNumber);
                        %get the allowed deviation and noise for this object
                        allowedDeviation = getappdata(snobfitgui, devHandle);
                        allowedNoise = getappdata(snobfitgui, noiseHandle);
                        %get the last entry in the data for this object
                        currentvalue = Data(end,currentfield);
                        currentset = Data(end,setfield);
                        %get class of object, useful if special rules - see below
                        class = objecttype(type).class;
                        %get condition for this object
                        condition = allConditions(1,m);
                        
                        %see if anything is tripped
                        
                        
                        

                        %does this object still need checking
                        if checkobject(m)
                            %get object details
                            objectNumber = objectNumbers(m);
                            type = objectconfig(objectNumber).type;
                            currentfield = objecttype(type).mainField;
                            %find where in the data this object is
                            currentfield = handles.actFields(1, m);
                            setfield = handles.setFields(1, m);
                            %get the handles to the dev and noise data
                            devHandle = sprintf('dev%d', objectNumber);
                            noiseHandle = sprintf('noise%d', objectNumber);
                            %get the allowed deviation and noise for this object
                            allowedDeviation = getappdata(snobfitgui, devHandle);
                            allowedNoise = getappdata(snobfitgui, noiseHandle);
                            %get the last entry in the data for this object
                            currentvalue = Data(end,currentfield);
                            currentset = Data(end,setfield);
                            %get class of object, useful if special rules - see below
                            class = objecttype(type).class;
                            %get condition for this object
                            condition = allConditions(1,m);
                            ratio=get(handles.ratiobox,'Value');
                            ratio2=get(handles.ratiobox2,'Value');
                            
                            
                            if strcmp(class, 'pump')
                                %if pump or valve resolution is given by the flowResolution
                                       resolution = objecttype(type).flowResolution;                       
                                %there is no separate set field for pumps or valves so just
                                %check that the settings have not changed in the last 2 mins
                                %and also that the set condition is within resolution of the
                                %calculated condition
                                %ratio=get(handles.ratiobox,'Value')
                                
                            elseif strcmp(class, 'valve')
                                resolution = objecttype(type).flowResolution;
                                
                                %other objects calculated in a different way but still need to
                                %know resolution
                            elseif strcmp(class, 'bpr')
                                %if bpr then resolution must be pressure
                                resolution = objecttype(type).setPressResolution;
                            elseif strcmp(class, 'temp')
                                %if temperature controller then resolution must be temp
                                resolution = 0.001;
                            else
                                %if not pump, valve, bpr or temp controller then not sure
                                %what it is, so don't check for resolution (set to inf)
                                resolution = inf;
                            end
                            
                            
                            
                            
                            
                            %check that there are not any changes to this objects setting,
                            %check that current value is close enough to set value and
                            %check that the range within current values is small enough and
                            %check within resolution of the calculated condition
                            %important code 1
                            if ~isempty(Data)
                            if ~any(Data(:,setfield) ~= currentset) && abs...
                                    (currentvalue - currentset) <= allowedDeviation...
                                    && (all((abs(Data(:,currentfield) - currentvalue))...
                                    <= allowedNoise)) &&...
                                    abs(condition - currentset) <= resolution
                                %                          if ~any(Data(:,setfield) ~= currentset) && abs...
                                %                             (currentvalue - currentset) <= allowedDeviation...
                                %                             && ~(any(abs(Data(:,currentfield) - currentvalue))...
                                %                             > allowedNoise) &&...
                                %                             abs(condition - currentset) <= resolution
                                %turn this object off
                                checkobject(m) = 0;
                                
                                
                                
                                %pico check for temperature controller
                                
                                picotest=get(handles.picotestCB,'Value');
                                
                                if strcmp(class, 'temp')
                                    if picotest
                                        %just check output in column 2 of picodata
                                        %object in port 1 of picolog
                                        PicoMaxDev=max(abs(picoData(:,2)-picoData(end,2)))
                                        if PicoMaxDev>=0.2
                                            checkobject(m) = 1;
                                        end
                                    end
                                end
                                
                                %                             if ~any(picoData(abs(currentvalue - currentset) <= allowedDeviation...
                                %                             && (all((abs(picoData(:,currentfield) - currentvalue))<= allowedNoise))...
                                %                             && abs(condition - currentset) <= resolution
                                
                                
                                
                            elseif ratio==1 && m==3
                                conditionratio=snobfit_data.conditions(snobfit_data.cycle,1)*snobfit_data.conditions(snobfit_data.cycle,3);
                                if ~any(Data(:,setfield) ~= currentset) &&...
                                        abs(conditionratio - currentset) <= resolution
                                    checkobject(m) = 0; %turn this object off
                                end
                                %% NEW 05112013
                            elseif ratio2==1 && m==2
                                conditionratio=snobfit_data.conditions(snobfit_data.cycle,1)*snobfit_data.conditions(snobfit_data.cycle,3)*snobfit_data.conditions(snobfit_data.cycle,2);
                                if ~any(Data(:,setfield) ~= currentset) &&...
                                        abs(conditionratio - currentset) <= resolution
                                    checkobject(m) = 0; %turn this object off
                                end
                                %% NEW 05112013
                            else
                                checkobject(m) = 1;
                            end
                        end
                        end
                    end
                    
                    % possibly add pico check here too?
                    disp('setting temperature check noise settings')
                     fileID = 'C:\Users\chmiprd1\Documents\MATLAB\Badger\drivers\Arduino\FLOWRATE.txt';
  try
        csvwrite(fileID,0.1)
  catch
      disp('should work once at the right temperature')
  end
                    %save the new checkobject status to the userdata of the timer
                    set(obj,'UserData', checkobject);
                    
                    %display status
                    set(handles.status2,'String', sprintf...
                        ('Checking Temp & Pressure Object(s): %s', sprintf...
                        ('%d, ', objectNumbers(checkobject == 1))))
                    
                    %if there are no objects left then can stop this timer
                    if ~any(checkobject)
                        balanceon=0;
                        %%find balance object for overnight runs
                        for objs=1:8
                            connectedObjects=(handles.connectedObjects);
                            if connectedObjects(objs,1)
                                type = objectconfig(objs).type;
                                currentfield = handles.actFields(1, objs);
                                %get class of object, useful if special rules - see below
                                class = objecttype(type).class;
                                if strcmp(class, 'balance')
                                    objectField = 5
                                    %find the position in serialdata for the field of interest
                                    %(first column is time followed by 5 columns for each object)
                                    BField=(objs-1) * 5 + objectField + 1;
                                    Weightfor1Snob=Data(end,BField)-Data(1,BField);
                                    balanceon=1;
                                end
                            end
                        end
                        %get condition for this object
                        timeelapsed=Data(end,1)-Data(1,1);
                        timeelapsed=timeelapsed*60*24;
                        totalvolume=totalflowrate*timeelapsed;
                        %assume a density of 0.7 for all pumps
                        density=0.7;
                        
                        totalmass=totalvolume*density;
                        
                        %allow some room for evaporation
                        totalmass=totalmass*.75;
                        %possibly add volumetric checks for each pump here????
                        %Future feature?
                        masscheck=1;
                        
                        ONtest=get(handles.OvernightCB,'Value');
                        
                        if ONtest
                            if balanceon==0
                                msgbox('You have selected an overnight experiment - without a balance connected - DO NOT PROCEED UNLESS RISK ASSESSMENT CONFIRMED!');
                                
                            end
                        end
                        
                        
                        if ONtest
                            if balanceon==1
                                if Weightfor1Snob<=totalmass
                                    
                                    condzero=zeros(1,size(handles.optimiseObjectNumbers,2));
                                    set(handles.status1,'String','Leak detected in overnight run - run start(timerfindall(Tag,snobfit_tim) when ready') %change the status box restart stabletim to restart
                                    set(handles.status2,'String','with apostrophes') %change status box
                                    %SET CONDITIONS TO ZERO
                                    try
                                        %in try catch loop due to communication errors with tempcontrollers
                                        setCondition(handles,condzero)
                                    catch
                                        pause(3)
                                        setCondition(handles,condzero)
                                    end
                                    stop(obj)
                                    masscheck=0;
                                    
                                end
                            end
                        end
                        
                        if masscheck==1
                            %display status
                            set(handles.status2, 'String', 'Temperature Ready, setting pumps')
                            %set clock for steady state waiting time
                            c = fix(clock);
                            %set waiting time
                            %                     set(handles.waiting_time,'string', sprintf(datestr(c)));
                            %
                            %                     %get the userdata for the GC file timer
                            %                     snobfit_data = get(timerfindall('Tag','snobfit_tim'),'UserData');
                            %                     %save the time to this userdata - in clock format (due to way time is
                            %                     %saved in gcfile)
                            %                     snobfit_data.stabletime = clock;
                            %                     %write this new userdata to the timer
                            %                     set(timerfindall('Tag','snobfit_tim'),'UserData',snobfit_data)
                            % settings = getDetails(hObject, eventdata, handles);
                            
                            %NEW STUFF FOR VARIABLE STEADY STATE
                            
                            %                     %reactor volume in mL move to GUI!
                            %                     gctimermod=timerfindall('Tag','GCfiletimer');
                            %
                            %                     %round to nearest second
                            %                     set(gctimermod,'StartDelay',0);
                            %
                            %                     %NEW STUFF FOR VARIABLE STEADY STATE
                            %
                            %
                            %                     %start gc file timer
                            %                     start(timerfindall('Tag','GCfiletimer'))
                            %
                            
                            ratio=get(handles.ratiobox,'Value');
                            ratio2=get(handles.ratiobox2,'Value');
                            
                            if ratio==0
                                
                                try
                                    %in try catch loop due to communication errors with tempcontrollers
                                    setCondition(handles, snobfit_data.conditions(snobfit_data.cycle,:))
                                catch
                                    pause(3)
                                    setCondition(handles, snobfit_data.conditions(snobfit_data.cycle,:))
                                end
                            else
                                snobfitsetcond=snobfit_data.conditions;
                                snobfitsetcond(snobfit_data.cycle,3)=snobfit_data.conditions(snobfit_data.cycle,1)*snobfit_data.conditions(snobfit_data.cycle,3);
                                %default code below - switched for NH072 17012014
                                %snobfitsetcond(snobfit_data.cycle,2)=snobfit_data.conditions(snobfit_data.cycle,1)*snobfit_data.conditions(snobfit_data.cycle,2);
                                
                                %Nick added 17012014 - CHECK
                                %floworg3=snobfitsetcond(snobfitdata.cycle,3)
                                
                                %%NEW 05112013
                                if ratio2==1
                                    %NEW 17012014
                                    %snobfitsetcond(snobfit_data.cycle,2)=snobfit_data.conditions(snobfit_data.cycle,3)*snobfit_data.conditions(snobfit_data.cycle,2);
                                    %ratio of pump 3 not pump 1 (where 3 =1*3)
                                    snobfitsetcond(snobfit_data.cycle,2)=snobfit_data.conditions(snobfit_data.cycle,3)*snobfit_data.conditions(snobfit_data.cycle,1)*snobfit_data.conditions(snobfit_data.cycle,2);
                                end
                                %%NEW 05112013
                                setCondition(handles, snobfitsetcond(snobfit_data.cycle,:))
                                
                            end
                            c = fix(clock);
                            
                            set(handles.status3, 'String', 'Flow Stability started at:')
                            set(handles.status4,'string', sprintf(datestr(c)));
                            start(timerfindall('Tag', 'stabletest'))
                            %stop this timer
                            stop(obj)
                        end
                        
                    end
                    
                    
                else
                    stop(obj)
                    set(timerfindall('Tag','pausetimc'),'UserData',snobfit_data)
                    start(timerfindall('Tag','pausetimc'))
                end
                
function stabletimcallback(obj, event, handles)

%get the handle to the main CO2 gui
MainGUI = handles.MainGUI;
%get the handle to the optimise gui
snobfitgui = handles.snobfitgui;
%standard field structure in the main GUI
fieldorder = {'currentTemp', 'setTemp', 'currentPress', 'setPress','flow'};
set(handles.status2, 'String', 'Checking Objects at:')
%set clock for steady state waiting time
c = fix(clock);
%set waiting time
set(handles.waiting_time,'string', sprintf(datestr(c)));

%get the objects details from from the main GUI
objectconfig = getappdata(MainGUI, 'objectConfig');
objecttype = getappdata(MainGUI, 'objectTypes');

%get the current array for check objects
checkobject = get(obj, 'UserData');
% get the object numbers from handles structure
objectNumbers = handles.enabledObjectNumbers;
%get the current poisition in data
currenttick = getappdata(MainGUI, 'serialDataTicker');
Data = getappdata(MainGUI, 'serialData');
%pico data
picoData = getappdata(MainGUI, 'picoData');

currenttime = Data(currenttick - 1, 1);

%overwrite so that only the last 1! mins are present in the data

%get the gctimer data
snobfit_data = get(timerfindall('Tag','snobfit_tim'),'UserData');
%get the calculated set conditions out of the timer data (and delink)
%take cycle number for row needed 13092013
allConditions = deLinkConds(handles, snobfit_data.conditions(snobfit_data.cycle,1:end));

%NEW STUFF FOR VARIABLE STEADY STATE
totalflowrate=0.0001;

for m = 1:size(objectNumbers, 2)
    %check the class of object
    %TIDY THIS UP LOTS OF FIELDS NOT USED
    Data = Data(Data(:, 1) >= currenttime - ((30000/60) / (60 * 24)), :);
    objectNumber = objectNumbers(m);
    type = objectconfig(objectNumber).type;
    currentfield = objecttype(type).mainField;
    %find where in the data this object is
    currentfield = handles.actFields(1, m);
    setfield = handles.setFields(1, m);
    %get the handles to the dev and noise data
    devHandle = sprintf('dev%d', objectNumber);
    noiseHandle = sprintf('noise%d', objectNumber);
    restHandle=sprintf('rest%d', objectNumber);
    rest=eval(strcat('get(handles.',restHandle,',''Value'')'));
    %get the allowed deviation and noise for this object
    allowedDeviation = getappdata(snobfitgui, devHandle);
    allowedNoise = getappdata(snobfitgui, noiseHandle);
    %get the last entry in the data for this object
    currentvalue = Data(end,currentfield);
    currentset = Data(end,setfield);
    %get class of object, useful if special rules - see below
    class = objecttype(type).class;
    %get condition for this object
    condition = allConditions(1,m);
    if strcmp(class, 'pump')

        if rest==1
            totalflowrate=totalflowrate+currentset
        end

    end

    try
        pause(2)
    catch
        disp('some kind of error with the stabletimer (steadystate timer)')
    end
end

FRNiPhPump = totalflowrate*0.1 %sets flow rate of pump 1 as a difined ratio of pumps 2,3 and 4.

pumpobjwriteflow(handles.NiPhPump, FRNiPhPump)


    pausetest=get(handles.pauseopt,'Value');
    if pausetest==0;

        steadyStateTime=str2num(get(handles.steadyStateTimeBox,'String'))
        reactorvolume=str2num(get(handles.reactorvolumetextbox,'String'))

        startdelayHPLC=(reactorvolume/(totalflowrate))*60*steadyStateTime
        startdelayHPLC=round(startdelayHPLC)
        set(handles.hplcstartdelaytext,'string',num2str(startdelayHPLC));

        %start gc file timer
        set(timerfindall('Tag','GCfiletimer'),'StartDelay',startdelayHPLC)
        start(timerfindall('Tag','GCfiletimer'))
        c = fix(clock);
        set(handles.status3, 'String', 'Injection timer started at:')
        set(handles.status4,'string', sprintf(datestr(c)));

        %stop this timer
        stop(obj)
    else
        stop(obj)
        set(timerfindall('Tag','pausetimc'),'UserData',snobfit_data)
        start(timerfindall('Tag','pausetimc'))
end

% --- Executes after reactor reaches steady state.
function gcfiletimcallback(obj, event, handles)

% %get the gcfile and log file path from the handles structure
gc_method_time = str2double(get(handles.methodTime,'String'));
%CHANGE THIS
%snobfit_data = get(timerfindall('Tag','snobfit_tim','UserData'));
snobfit_data = get(timerfindall('Tag','snobfit_tim'),'UserData');
%snobfit_data = snobfit_data.UserData
%find how long ago last gc was taken
lastgctime = (now-snobfit_data.gc_identity(end))*60*24;

%if it is not the last condition in this call, just record the time, turn
%the loop, and return to the main timer.
if lastgctime >= gc_method_time
    %if yes
    set(handles.status2, 'String', 'Getting UV file')
    snobfit_data.gc_identity(snobfit_data.measurement_number) = now;
    %turn the sample loop
    if handles.GCoption
        %take sample using direct serial control of sample loop
        sampleloopobjsample(handles.GCserialObject)
    else
        %take sample using the task kill method (written into function
        %file for easy change of which task to kill
        sampleloopobjsample2
    end
    
        counterstr = snobfit_data.measurement_number

                    stringcount = num2str(counterstr)

                    path = handles.pathUV
                    %path1 = strcat(path,'\experimentfiles\');
                    path2 = strcat(path,'\raw\');

                    %handles.path1 = path1;

                    %mkdir(path1);
                    mkdir(path2);

                    warning('OFF');

                    %predictionfile = '\Prediction - Linear (AVG).txt';
                                     
                    rawdatafile = '\.txt';

                    %prediction = strcat(path,predictionfile);
                    raw = strcat(path,rawdatafile);

                    %predictionnewname = strcat(stringcount,'.txt');
                    rawnewname = strcat(stringcount,'.txt');

                    %predictionmove = strcat(path1,predictionnewname);
                    rawmove = strcat(path2,rawnewname);

                    %movefile(prediction,predictionmove,'f');

                    movefile(raw,rawmove,'f');
    
    
    %increase the cycle number
    snobfit_data.cycle = snobfit_data.cycle + 1;
    %increase the measurement number
    snobfit_data.measurement_number = snobfit_data.measurement_number + 1;
    %update the snobfit data
    set(timerfindall('Tag','snobfit_tim'),'UserData',snobfit_data)
    %restart the snobfit timer to run the next conditions
    
    pausetest=get(handles.pauseopt,'Value');
    if pausetest==0;
        
        nreqcheck=size(snobfit_data.conditions,1)
        if snobfit_data.cycle-1 == nreqcheck
            set(timerfindall('Tag','snobfit_tim'))%,'StartDelay',snobchromdelay)
            set(handles.status2, 'String', 'Extracting UV/Vis file')
        end
        
    else
        
        set(timerfindall('Tag','snobfit_tim'),'StartDelay',10)
        
    end
    
    pause(0.2)
                    
    start(timerfindall('Tag','snobfit_tim'))
    
else
    set(timerfindall('Tag','pausetimc'),'UserData',snobfit_data)
    start(timerfindall('Tag','pausetimc'))
end
%set the next conditions
stop(obj)
    
% --- Boring code which doesn't seem to do anything interesting, you
% probably don't want to change anything here. 




function setCondition(handles, condition)
%used to change the condition during the simplex operation

%get the handle for the main CO2 gui
MainGUI = handles.MainGUI;

%get info from the appdata
config = getappdata(MainGUI,'objectConfig');
types = getappdata(MainGUI,'objectTypes');

%use deLink function to generate the actual condition matrix to send (deal
%with objects linked together)
allConditions = deLinkConds(handles, condition);

%loop through each condition
for i = 1:size(allConditions, 2)
    %get objectNumber
    objectNumber = handles.enabledObjectNumbers(1, i);
    %get the type of object from config structure
    objectType = config(objectNumber).type;
    %get the serial object from main GUI
    serialobj = getappdata(MainGUI, sprintf...
        ('serialObject%d', objectNumber));
    %get the class of the serial object
    class = types(objectType).class;

    %if this is a Jasco BPR - SPECIAL CASE!
    if strcmp(class, 'bpr')
        %get the last row filled by timers in main gui
        tick = getappdata(MainGUI,'serialDataTicker') - 1;
        %workout which field has the current set pressure in it, as this is
        %a BPR then always the 4th field +1 for time hence + 5
        fieldNo = ((objectNumber-1) * 5) + 5;
        %get the current pressure from the serial data from the main GUI
        CurrentP = getappdata(MainGUI, 'serialData');
        CurrentP = CurrentP(tick, fieldNo);
        %send the command for slow P changes
        
        recordfield = sprintf('collectDataFlag%d', objectNumber);
setappdata(MainGUI, recordfield, 0)
%setappdata(handle, recordfield, 0) error??? 250117
%set the pressure
bprobjwritesetpress(serialobj, allConditions(1, i))
%set the record flag back on
setappdata(MainGUI, recordfield, 1)
%setappdata(handle, recordfield, 1) error??? 250117

        
        %bprslowPchange(serialobj, CurrentP, allConditions(1, i),...
         %   MainGUI, objectNumber)
         
         %code errors needs work!
         
        %if its a temperature controller
    elseif strcmp(class, 'temp')
        %turn recording off whilst command is sent
        recordfield = sprintf('collectDataFlag%d', objectNumber);
        setappdata(MainGUI,recordfield,0)
        %try to send command
        try
        feval(str2func(types(objectType).mainCommand), serialobj,...
            allConditions(1, i));
        catch
            timestamp = clock;
            readings = tempobjreadall(serialobj);
            diff = abs(readings{2}-allConditions(1, i));
            while diff > 0.001
                if etime(clock, timestamp) < 60
                    try
                        pause(0.5)
                        tempobjwritesettemp(serialobj, allConditions(1, i))
                        readings = tempobjreadall(serialobj);
                        diff = abs(readings{2}-allConditions(1, i));
                    catch
                        readings = tempobjreadall(serialobj);
                        diff = abs(readings{2}-allConditions(1, i));
                    end
                else
                    error('Could not change settings for temp controller')
                end
            end
        end
        %turn recording on
        setappdata(MainGUI, recordfield, 1)
        
        %anything else then use a standard way to change conditions
    else
        %turn recording off whilst command is sent
        recordfield = sprintf('collectDataFlag%d', objectNumber);
        setappdata(MainGUI,recordfield,0)
        %send command
        feval(str2func(types(objectType).mainCommand), serialobj,...
            allConditions(1, i));
        %turn recording on
        setappdata(MainGUI, recordfield, 1)
    end
end
        
function bprslowPchange(serialobj, CurrentP, NewP, handle, objectNumber)
%function designed to change the pressure setting on a JASCO BPR with a
%ramp instead of a step - CAN ONLY BE USED WITH MAIN CO2GUI

%is the pressure increasing / decreasing / staying the same
direction = sign(NewP - CurrentP);
starttim = now;

%so if direction is not zero then P is changing and need to start timer
if direction ~=0
    %set up timer
   BPRPchange=(timer('Period', 5, 'TasksToExecute', inf, 'TimerFcn',...
        {@BPRtimercallback, serialobj, CurrentP, NewP, direction,....
        starttim, handle, objectNumber}, 'ExecutionMode',...
        'fixedSpacing', 'Tag', 'BPRPchange','Name','Timer-56'));
    %start timer
    start(timerfindall('Tag','BPRPchange'));
else
    %do nothing
end

function BPRtimercallback(obj, event, serialobj, CurrentP, NewP, direction, starttim, handle, objectNumber)

time = (now-starttim) * (24*60*60); %time in seconds since start
%added by Rich 19/12/16 - not certain if correct!
%SetP = NewP;
SetP=NewP;
direction = sign(NewP - CurrentP);

if direction == 1 %so if pressure going up can change at 0.2 bar/s
    grad = 0.6;
    SetP = CurrentP + (grad * time);
    
    %if the calc set pressure greater than requested than round down and
    %stop timer
    if SetP >= NewP
        SetP = NewP;
        stop(obj)
        delete(obj)
    end
    SetP = roundto(SetP, 1);
    
elseif direction == -1 %so if pressure is going down change at -1 bar/s
    grad = -1;
    SetP = CurrentP + (grad*time);
    
    %if the calc set pressure less than requested than round up and stop
    %timer
    if SetP <= NewP
        SetP = NewP;
        stop(obj)
        delete(obj)
    end
    SetP = roundto(SetP, 1);
end

if NewP - CurrentP <=10
    SetP=NewP;
        SetP = roundto(SetP, 1);
end

%round the SetP to the nearest 0.1 bar to stop all the warnings about been
%above the accuracy of the BPR

%stop recording for this object whilst command is sent
recordfield = sprintf('collectDataFlag%d', objectNumber);
setappdata(handle, recordfield, 0)
%set the pressure
bprobjwritesetpress(serialobj, SetP)
%set the record flag back on
setappdata(handle, recordfield, 1)

function stablestartcallback(obj, event, handles)
        %create array which keeps track of which objects to keep checking and store
        %in userdata
        set(obj, 'UserData', ones(1, size(handles.enabledObjectNumbers, 2)));    

function pausetimcallback(obj, event, handles)
pausetest=get(handles.pauseopt,'Value');
%snobfit_data=get(handles.snobfit_data);
if pausetest==0;
    start(timerfindall('Tag','snobfit_tim'))
    stop(obj)
else
    condzero=zeros(1,size(handles.optimiseObjectNumbers,2));
    set(handles.status1,'String','Paused') %change the status box
    set(handles.status2,'String',datestr(clock)) %change status box
    %SET CONDITIONS TO ZERO
    try
        %in try catch loop due to communication errors with tempcontrollers
        setCondition(handles,condzero)
    catch
        pause(3)
        setCondition(handles,condzero)
    end
    stop(obj)
end

function steadyStateTimeBox_Callback(hObject, eventdata, handles)
checkNumericCallback(hObject, eventdata, handles)

% parses contents
newNumber = str2double(get(hObject, 'String'));

%need to make sure that number is at least 0
if newNumber < 0
    errordlg('number must be greater than 0')
    %remove contents from box
    set(hObject, 'String', '')
end

% Update handles structure
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function steadyStateTimeBox_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject, 'BackgroundColor'), get(0, 'defaultUicontrolBackgroundColor'))
    set(hObject, 'BackgroundColor', 'white');
end

function maxRetentionTime_Callback(hObject, eventdata, handles)
% checks contents to see if they are numeric
checkNumericCallback(hObject, eventdata, handles)

% --- Executes during object creation, after setting all properties.
function maxRetentionTime_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject, 'BackgroundColor'), get(0, 'defaultUicontrolBackgroundColor'))
    set(hObject, 'BackgroundColor', 'white');
end

% --- Executes during object creation, after setting all properties.
function snobfitgui_CreateFcn(hObject, eventdata, handles)

% --- Executes on button press in link1.
function link1_Callback(hObject, eventdata, handles)

try
    %try to open the linktogui
    linktogui(hObject, eventdata, handles)
catch
    errmsg = lasterror; %get the error stucture which might have been generated above
    errmsg = errmsg.message; %get message from struture
    endFirstLine = regexp(errmsg, '[\n\r]'); %find where the first line ends
    errmsg = errmsg((endFirstLine+1):end); %remove first line from message
    errordlg(errmsg) %display popup box for user to see
end

% Update handles structure
guidata(hObject, handles);

function snobfitgui_CloseRequestFcn(callingObject, eventdata, handles)
% callingObject handle to CO2gui (see GCBO)
%see if the button for start is on or off (this should indicate if simplex
%is running or not)

selection = questdlg('Really Close?',...
    'Close?',...
    'Yes', 'No', 'No');
if strcmp(selection,'Yes') %user selects yes

    %get timers
    simplextimer = timerfindall('Tag','simplextimer');
    BPRchangetimer = timerfindall('Tag','BPRPchange');
    GCfiletimer = timerfindall('Tag','GCfiletimer');

    if ~isempty(simplextimer) %if there is any timers with this tag
        stop(simplextimer) %stop timer
        delete(simplextimer) %delete timer
    end
    clear('simplextimer') %delete pointer to timer

    if ~isempty(BPRchangetimer) %if there is any timers with this tag
        stop(BPRchangetimer) %stop timer
        delete(BPRchangetimer) %delete timer
    end
    clear('BPRchangetimer') %delete pointer to timer

    if ~isempty(GCfiletimer) %if there is any timers with this tag
        stop(GCfiletimer) %stop timer
        delete(GCfiletimer) %delete timer
    end
    clear('GCfiletimer') %delete pointer to timer

    % defines the possible windows which can be opened from the optmiseGUI
    windows = { 'linktoHandle';...
        'noisesettingHandle'};

    % for each window
    for n = 1:numel(windows)
        % gets the window handle (it'll be empty if it isn't there)
        windowHandle = getappdata(callingObject, windows{n});

        % if its not empty and its a valid handle, close it
        if ~isempty(windowHandle) && ishandle(windowHandle)
            % closes the window
            delete(windowHandle)
        end
    end

    delete(handles.snobfitgui) %delete the gui

else %user does not select yes
    return %go back to what ever caused this to try and close
end

% --- Executes on button press in noise.
function noise_Callback(hObject, eventdata, handles)
noisesettingsnob(hObject, eventdata, handles)

% --- Executes on button press in altGCcheck.
function altGCcheck_Callback(hObject, eventdata, handles)

%this is used to set the method by which GC samples are taken, i.e. control
%via matlab or control by external software (e.g. GCsolution) or other
%device (e.g. GC timer which can't be controlled via matlab)

%get the checkbox status
checkbox = get(hObject,'Value');

%if selected
if checkbox
    %disable the GCselction box to stop user changing which serial object
    %to use once it has been chosen
    set(handles.GCselect,'Enable','Off')
%  set(handles.GCselect2,'Enable','Off')
    %check that there is some GC options
    if isfield(handles,'GCserialNumber')
        %get the indicated serial object from the mainGUI appdata
        handles.GCserialObject = getappdata(handles.MainGUI,...
            sprintf('serialObject%d',handles.GCserialNumber(get(handles.GCselect,'Value'),1)));
%         handles.GCserialObject2 = getappdata(handles.MainGUI,...
%             sprintf('serialObject%d',handles.GCserialNumber(get(handles.GCselect2,'Value'),1)));
        handles.GCoption = 1;
    else
        %if not then have to use old GC method
        handles.GCoption = 0;
        %warn user and disable this box
        warndlg('Problem with GC selection - USING OLD METHOD','GC PROBLEM!!')
        set(hObject,'Value',0,'Enable','Off')
    end
else
    %enable the GCselection box (incase user wants to change selection)
    set(handles.GCselect,'Enable','On')
%       set(handles.GCselect2,'Enable','On')
    %set GC option back to old method
    handles.GCoption = 0;
end

% Update handles structure
guidata(hObject, handles);

% --- Executes on selection change in GCselect.
function GCselect_Callback(hObject, eventdata, handles)

% --- Executes during object creation, after setting all properties.
function GCselect_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --------------------------------------------------------------------
function save_Callback(hObject, eventdata, handles)
% hObject    handle to save (see GCBO)
%ask user where to save file
[name, path] = uiputfile('*.mat', 'Select File Location');
%check that user selected somewhere
if ~isequal(path, 0) && ~isequal(name, 0)
    %if so then try to save everything
    
    %first make blank structure
    saveData = struct('linked', zeros(8,8), 'objectTypes',...
    zeros(1,8), 'objectEnabled', zeros(1,8), 'dims', zeros(1,1),...
    'mins', zeros(1,8), 'maxs', zeros(1,8), 'initialConds', zeros(9,8),...
    'maxIterations', 0,'steadyTime', 0,'COVLim', 0,'predictP', 0,...
    'YoptMethod', 0,'YoptMin', 0,'YoptMax',0,'YoptMargin', 0,...
    'GCminRT', 0, 'GCmaxRT', 0, 'GCMethodT', 0, 'GCoption', 0 ,...
    'GCObjectNumber', 0, 'Target', 0);
    
    %get the current linked status
    saveData.linked = getappdata(handles.snobfitgui, 'linked');
    
    %get the stuff to work out the type for each object
    %get the current configuration of objects from Main GUI
    objectTypes = getappdata(handles.MainGUI,'objectConfig');
    objectTypes = [objectTypes.type]';
    %remove unwanted info and add to save structure
    saveData.objectTypes = objectTypes(1:8,1);
    
    %work out which objects are actually enabled    
    for i = 1:8
        saveData.objectEnabled(1, i) =...
            get(handles.(sprintf('checkbox%d', i)), 'value');
    end
    
    
    %get the current number of dimensions (mainly for error checking)
    saveData.dims = str2double(get(handles.dimensionsBox, 'String'));
    
    %get all the stuff for the mins, maxs & initial conditions
    %loop through each object/column
    for col = 1:8
        %get the min and max valus
        saveData.mins(1, col) = str2double(get...
            (handles.(sprintf...
            ('min%d', col)), 'String'));
        saveData.maxs(1, col) = str2double(get...
            (handles.(sprintf...
            ('max%d', col)), 'String'));
        %loop through each row in the initial conditions and get
        %the values
        for row = 1:9
            saveData.initialConds(row, col) = str2double(get...
                (handles.(sprintf...
                ('initial%d_%d', row, col)), 'String'));
        end
    end
    
    %get all values for general settings
    saveData.maxIterations =...
        str2double(get(handles.iterationsBox, 'String'));
    saveData.steadyTime =...
        str2double(get(handles.steadyStateTimeBox, 'String'));
    saveData.COVLim = str2double(get(handles.pBox, 'String'));
    %check if predicition is on for mid point
    if get(handles.predictPBox, 'Value')
        saveData.predictP = 1;
    else
        saveData.predictP = 0;
    end
    %check the fitting method used (0 is gaussian, 1 is poly) 
    if get(handles.gaussianBox, 'Value')
        saveData.YoptMethod = 0;
    else
        saveData.YoptMethod = 1;
    end
    
    %Yopt Stuff
    saveData.YoptMin = str2double(get(handles.YoptMinBox, 'String'));
    saveData.YoptMax = str2double(get(handles.YoptMaxBox, 'String'));
    saveData.YoptMargin = str2double(get(handles.YoptMarginBox,'String'));
    
    %GC stuff
    %get the values
    saveData.GCminRT = str2double(get(handles.minRetentionTime,'String'));
    saveData.GCmaxRT = str2double(get(handles.maxRetentionTime,'String'));
    saveData.GCMethodT = ...
        str2double(get(handles.methodTime,'String'));
    %check the GC method (may need to change this later when
    %modified how GC method options works)
    if get(handles.altGCcheck, 'Value')
        saveData.GCoption = 1;
        saveData.GCObjectNumber =...
            handles.GCserialNumber(get...
            (handles.GCselect,'Value'), 1);
%         saveData.GCObjectNumber2 =...
%             handles.GCserialNumber(get...
%             (handles.GCselect2,'Value'), 1);
    else
        saveData.GCoption = 0;
    end
    
    %save target number
    saveData.target = get(handles.targetSelect, 'Value');
    %save target string (i.e. name of the target)
    saveData.targetString = get(handles.targetSelect,'String');
    saveData.targetString = saveData.targetString{saveData.target};
    
    %write to mat file (maybe add option to have text file later)
    save(fullfile(path, name),'saveData')
    %display message
    helpdlg('file saved successfully')
        
end
%if user does not select file do nothing

% --------------------------------------------------------------------
function load_Callback(hObject, eventdata, handles)
% hObject    handle to load (see GCBO)



%ask user which file to load from
[name, path, filter] =...
    uigetfile('*.mat', 'Select a file to load from');
%check that a file was selected
if ~isequal(name, 0) && ~isequal(path, 0)
    %if a file was selected check the type
    if isequal(filter, 1)
        %check contains the expected structure
        fileinfo = whos('-file', fullfile(path, name));
        if ~strcmp({fileinfo.name}, 'saveData') ||...
                ~strcmp({fileinfo.class}, 'struct')
            errordlg('file does not contain correct information')
        else
            %file should be okay now so actually load it
            load(fullfile(path, name), 'saveData')
            
            %preallocate an assumed okay response to below questions
            userAns = 'Yes';
            %check if possible to load previous settings into current GUI
            %first test object type
            MainGUIData = getappdata(handles.MainGUI);
            MainGUIObjConfig = MainGUIData.objectConfig;
            currentObjectTypes = [MainGUIObjConfig.type]';
            currentObjectTypes = currentObjectTypes(1:8,1);
            if ~all(currentObjectTypes == saveData.objectTypes)
                %if there is a mismatch ask user what to do about it
                userAns = questdlg('Object types in saved file don''t match current object types, Continue?',...
                    'Object Type Mismatch', 'Yes', 'No', 'No');
            end
            %check if user says yes (or not asked yet)
            if strcmp(userAns, 'Yes')
                %now check which objects are connected and enabled in the
                %main GUI (can't use them if not)
                currentEnabled = [MainGUIObjConfig.enabled];
                currentEnabled = currentEnabled(1:8);
                connectedObjects = zeros(1,8);
                for obj = 1:8
                    if isfield(MainGUIData, sprintf('serialObject%d',obj))
                        connectedObjects(1,obj) = 1;
                    else
                        connectedObjects(1,obj) = 0;
                    end
                end 
                if ~all(currentEnabled(saveData.objectEnabled==1)==1)...
                        || ~all(connectedObjects...
                        (saveData.objectEnabled==1)==1)
                    %if there is a mismatch ask user what to do about it
                    userAns = questdlg('Connected and Enabled Objects in saved file don''t match current objects, Continue?',...
                    'Object Type Mismatch', 'Yes', 'No', 'No');
                end
                %check if user says yes (or not asked yet)
                if strcmp(userAns, 'Yes')
                    %sort out enabled objects (saved file could be more
                    %resrictive)
                    
                    %good point to update the linked status as
                    %checked later duing the enabled objects callback
                    setappdata(handles.snobfitgui,'linked',...
                        saveData.linked)                    
                    %enable the correct objects 
                    for obj=1:8
                        set(handles.(sprintf('checkbox%d', obj)),'Value',...
                            saveData.objectEnabled(obj))
                    end
                    %run the normal enabled objects callback with the first
                    %one which is enabled in the save data
                    enableCallback(handles.(sprintf('checkbox%d',...
                        find(saveData.objectEnabled,1,'first'))),...
                        eventdata, handles)
                    
                    %now work through all other information (note that
                    %stuff might be put into disabled boxes - but this does
                    %allow user to see what previously used)
                    
                    %object settings
                    for obj = 1:8
                        %mins and maxs
                        set(handles.(sprintf('min%d', obj)),'String',...
                            saveData.mins(obj))
                        set(handles.(sprintf('max%d', obj)),'String',...
                            saveData.maxs(obj))
                        %initialConds
                        for row = 1:9
                            set(handles.(sprintf('initial%d_%d',...
                                row, obj)),'String',...
                                saveData.initialConds(row, obj))
                        end
                    end
                    %general settings
                    set(handles.iterationsBox, 'String',...
                        saveData.maxIterations)
                    set(handles.steadyStateTimeBox, 'String',...
                        saveData.steadyTime)
                    set(handles.pBox, 'String',...
                        saveData.COVLim)
                    if saveData.YoptMethod==1
                        set(handles.polynomialBox,'Value',1)
                        set(handles.gaussianBox,'Value',0)
                    else
                       set(handles.polynomialBox,'Value',0)
                        set(handles.gaussianBox,'Value',1)
                    end
                    set(handles.predictPBox, 'Value', saveData.predictP)
                    %GC settings
                    set(handles.minRetentionTime, 'String',...
                        saveData.GCminRT)
                    set(handles.maxRetentionTime, 'String',...
                        saveData.GCmaxRT)
                    set(handles.methodTime, 'String',...
                        saveData.GCMethodT)
                    %Check for GC method - This section will need updating
                    %when other code for GC is improved
                    if saveData.GCoption
                        %find which out of the possible objets was selected
                        menuValue = find(saveData.GCObjectNumber ==...
                            handles.GCserialNumber);
                        if isempty(menuValue)
                            %if there is no match, warn user
                            warndlg('No match for samples loops setting to old method')
                            %set option as non-direct link
                            set(handles.altGCcheck, 'Value', 0)
                        else
                        %if there is a match then set values
                        set(handles.GCselect, 'Value', menuValue)
                        set(handles.altGCcheck, 'Value', 1)
                        end
                    end
                    % run the callback for this object so that snobfitguiUV
                    % has the correct settings
                    altGCcheck_Callback(handles.altGCcheck, eventdata,...
                        handles)
                    %Yopt Settings
                    set(handles.YoptMinBox, 'String', saveData.YoptMin)
                    set(handles.YoptMaxBox, 'String', saveData.YoptMax)
                    set(handles.YoptMarginBox, 'String',...
                        saveData.YoptMargin)
                    
                    %get possible options for target drop down box
                    targetMax =...
                        size(get(handles.targetSelect, 'String'), 1);
                    %check that the saved option is at least possible with
                    %current length of list (does not mean it's a definate
                    %match)
                    if saveData.target > targetMax
                        %if can't set then assume option 1 and warn user
                        warndlg('Can''t match target setting to option 1')
                        set(handles.targetSelect, 'Value', 1)
                    else
                        %set target drop down box to set value
                        set(handles.targetSelect, 'Value', saveData.target)
                        %get the current string (i.e. name of the target)
                        currTargetString =...
                            get(handles.targetSelect,'String');
                        currTargetString =...
                            currTargetString{saveData.target};
                        %check that string match
                        if ~strcmp(currTargetString,saveData.targetString)
                            %if not then warn user
                            warndlg('Target names don''t match possible error')
                        end
                    end
                end
                %if user selects no then don't load anything 
            end
            %if user selects no then don't load anything
        end        
    else
        errordlg('incorrect file type please select a *.mat file')
    end
end
%do nothing if no file selected

% --- Executes on button press in viewButton.
function viewButton_Callback(hObject, eventdata, handles)
%get timer
simplextimer = timerfindall('Tag', 'simplextimer');
%check that there is one
if isempty(simplextimer)
    errordlg('can''t find the main simplex timer to extract data from')
else
    %get data from the timer
    simplexData = get(simplextimer, 'UserData')
    %run the view command
    simplexview(simplexData)
end

% --- Executes on button press in yield_check.
function yield_check_Callback(hObject, eventdata, handles)

% --- Executes on button press in sty_check.
function sty_check_Callback(hObject, eventdata, handles)

% --- Executes on button press in efac_check.
function efac_check_Callback(hObject, eventdata, handles)

% --- Executes on button press in cost_check.
function cost_check_Callback(hObject, eventdata, handles)

% --- Executes on button press in BSfac_check.
function BSfac_check_Callback(hObject, eventdata, handles)

% --- Executes on selection change in targetSelect.
function targetSelect_Callback(hObject, eventdata, handles)

% --- Executes during object creation, after setting all properties.
function targetSelect_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes on button press in viewFunctionBut.
function viewFunctionBut_Callback(hObject, eventdata, handles)
edit('responseFunction.m')

function allConditions = deLinkConds(handles, condition)
%preallocate for below
allConditions = zeros(size(handles.enabledObjectNumbers));
allConditions=condition;

handles.linked = getappdata(handles.snobfitgui, 'linked');
        linkedmat=zeros(8,8);
        for m = 1:8
        
                        linkhandle = sprintf('FRobj%d',(m));
                        link=str2num(eval(strcat('get(handles.',linkhandle,',''String'')')));
                        FRhandle = sprintf('flowratio%d',(m));
                        FRlink=str2num(eval(strcat('get(handles.',FRhandle,',''String'')')));
                        if link>=1
                            linkedmat(link,m)=FRlink;
                        end
                        setappdata(handles.snobfitgui,'linked',linkedmat)
        end

for i = 1:size(handles.optimiseObjectNumbers, 2)
    %write condition in for this object
    %get objects linked to this object
    linkedObjects = find...
        (handles.linked(handles.optimiseObjectNumbers(1, i), :));
    %check that this object has a link
    if ~isempty(linkedObjects)
        for j = 1:size(handles.optimiseObjectNumbers,2)
            if handles.optimiseObjectNumbers(1, j)==linkedObjects;
                allConditions(j)=condition(1,i)*handles.linked(j,linkedObjects);               
            end
            if handles.linked(i,j)==-1
                allConditions(j)=condition(1,i)*condition(1,j);
            end
            
            %%%%% Adam edit: optimisation of flow rate ratios %%%%%
            %%%%% Experiment specific, change as required %%%%%
            

            
        end
    end
end

% --- Executes during object creation, after setting all properties.
function noise_CreateFcn(hObject, eventdata, handles)
% hObject    handle to noise (see GCBO)

function nreqBox_Callback(hObject, eventdata, handles)

% checks contents to see if they are numeric
checkNumericCallback(hObject, eventdata, handles)

% parses contents
newNumber = str2double(get(hObject, 'String'));

%need to make sure that number is at least 1
newNumber = max(1, newNumber);

%round number (towards inf.) as can't have fractional number of exps.
newNumber = ceil(newNumber);

% re-updates box
set(hObject, 'String', int2str(newNumber))

% Update handles structure
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function nreqBox_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%function designed to be run anytime all the settings need to be got out of
%the boxes in the gui
function settings = getDetails(hObject, eventdata, handles)

% fetches the max number of iterations and number of exps per
% iterations (error checking already done above)
maxIterations = str2double(get(handles.iterationsBox, 'String'));
nreq = str2double(get(handles.nreqBox, 'String'));

%fetch steady state time
steadyStateTime = str2double(get(handles.steadyStateTimeBox,...
    'String'));
%check that a value is present
assert(~isnan(steadyStateTime),...
    'a value for steady state time must be entered')
%fetch probabilty
prob = str2double(get(handles.pBox,...
    'String'));
%check that a value is present
assert(~isnan(prob),...
    'a value for probability must be entered')
reactorvolume = str2double(get(handles.reactorvolumetextbox,...
    'String'));
%check that a value is present
assert(~isnan(reactorvolume),...
    'a value for steady reactor volume (mL) must be entered')

%assume error is zero (for snobfit function) may have to put in an
%input for this later!

%-----GC STUFF PUT BACK IN LATER--------------------
% fetch and check the GC details
minRetentionTime = str2double(get(handles.minRetentionTime,...
    'String'));
maxRetentionTime = str2double(get(handles.maxRetentionTime,...
    'String'));
methodTime = str2double(get(handles.methodTime, 'String'));

if isnan(minRetentionTime)
    error('a value for the the min retention time must be entered')
elseif isnan(maxRetentionTime)
    error('a value for the the max retention time must be entered')
elseif isnan(methodTime)
    error('a value for the the method time must be entered')
elseif minRetentionTime >= maxRetentionTime...
        || minRetentionTime > methodTime
    error...
        ('Min retention time must be less than max retention time & method time')
elseif maxRetentionTime > methodTime
    error('Max retention time must be less than method time')
end

%get target
target = get(handles.targetSelect,'Value');

%preallocate min, max and dx arrays
minBounds = zeros(size(handles.optimiseObjectNumbers));
maxBounds = zeros(size(handles.optimiseObjectNumbers));
dxValues = zeros(size(handles.optimiseObjectNumbers));
%get all the min, max and dxs for each object
for i = 1:size(handles.optimiseObjectNumbers, 2)
    objNum = handles.optimiseObjectNumbers(1, i);
    minBounds(1, i) = ...
        str2double(get(handles.(sprintf('min%d',objNum)),'String'));
    maxBounds(1, i) = ...
        str2double(get(handles.(sprintf('max%d',objNum)),'String'));
    dxValues(1, i) = ...
        str2double(get(handles.(sprintf('dx%d',objNum)),'String'));
end
%check min, max and dx arrays have been entered
assert(all(~isnan(minBounds)),...
    'values for all min bounds must be entered')
assert(all(~isnan(maxBounds)),...
    'values for all max bounds must be entered')
assert(all(~isnan(dxValues)),...
    'values for all dx values must be entered')
%check that all mins are less than maxs
assert(all(minBounds < maxBounds),...
    'values for all min bounds must be less than max bounds')
%check that dx is less than maxBounds (otherwise impossible to move)
assert(all(dxValues < maxBounds),...
    'dx values must be less than max bounds')

%make structure to store all the data in (edit when put GC stuff back)
settings = struct('maxIterations', maxIterations, 'nreq', nreq, ...
    'steadyStateTime',steadyStateTime, 'prob', prob, 'target', target, ...
    'minBounds', minBounds, 'maxBounds', maxBounds, 'dxValues', dxValues);
handles.setttings = settings;

function dimensionsBox_Callback(hObject, eventdata, handles)

function COV_box_Callback(hObject, eventdata, handles)

% --- Executes during object creation, after setting all properties.
function COV_box_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function reactorvolumetextbox_Callback(hObject, eventdata, handles)

% --- Executes during object creation, after setting all properties.
function reactorvolumetextbox_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes on button press in pauseopt.
function pauseopt_Callback(hObject, eventdata, handles)
% hObject    handle to pauseopt (see GCBO)
pausetest=get(handles.pauseopt,'Value');
set(timerfindall('Tag','snobfit_tim'),'StartDelay',10)
if pausetest==0;
    start(timerfindall('Tag','snobfit_tim'))
    
end
% Hint: get(hObject,'Value') returns toggle state of pauseopt

% --- Executes on button press in ratiobox.
function ratiobox_Callback(hObject, eventdata, handles)

% --- Executes on button press in resetcond.
function resetcond_Callback(hObject, eventdata, handles)

 start(timerfindall('Tag','snobfit_tim'))

% --- Executes during object creation, after setting all properties.
function resetcond_CreateFcn(hObject, eventdata, handles)

function ratiobox2_Callback(hObject, eventdata, handles)
   
function IntStdMin_Callback(hObject, eventdata, handles)

% --- Executes during object creation, after setting all properties.
function IntStdMin_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function IntStdMax_Callback(hObject, eventdata, handles)

% --- Executes during object creation, after setting all properties.
function IntStdMax_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes on button press in OvernightCB.
function OvernightCB_Callback(hObject, eventdata, handles)
msgbox('You have selected an overnight experiment - weight is now being monitored. Ensure that 1.) HPLC waste is empty 2.) Enough volume for experiment waste 3.) All solvents and reagents are filled','Warning - Overnight Experiment');

% --- Executes on button press in picotestCB.
function picotestCB_Callback(hObject, eventdata, handles)
msgbox('You have selected picolog checking for stability - this code currently checks the item attached to port 1 and ensures all values are within 0.3 C over the steady state time');

% --- Executes on button press in _but.
function Plotsnob_but_Callback(hObject, eventdata, handles)
% Plotsnob check
load(handles.file,'request');
load(handles.file,'f');
load(handles.file,'x');
load(handles.file,'fbest');
load(handles.file,'xbest');
plotsnob(x,-f,xbest,-fbest,request);

function DADsignalobj_Callback(hObject, eventdata, handles)

% --- Executes during object creation, after setting all properties.
function DADsignalobj_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function DADsignalIS_Callback(hObject, eventdata, handles)

% --- Executes during object creation, after setting all properties.
function DADsignalIS_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- If Enable == 'on', executes on mouse press in 5 pixel border.
% --- Otherwise, executes on mouse press in 5 pixel border or over link1.
function link1_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to link1 (see GCBO)

% --- Executes on key press with focus on link1 and none of its controls.
function link1_KeyPressFcn(hObject, eventdata, handles)
% hObject    handle to link1 (see GCBO)
% eventdata  structure with the following fields (see MATLAB.UI.CONTROL.UICONTROL)
%	Key: name of the key that was pressed, in lower case
%	Character: character interpretation of the key(s) that was pressed
%	Modifier: name(s) of the modifier key(s) (i.e., control, shift) pressed
 
% --- Executes on button press in DOEbox.
function DOEbox_Callback(hObject, eventdata, handles)
% hObject    handle to DOEbox (see GCBO)

% --- Executes on button press in editdoe.
function editdoe_Callback(hObject, eventdata, handles)
% dat = [1 2 3 4 5];
set(handles.doeuitable, 'Visible', 'on');
set(handles.addrow, 'Visible', 'on');
set(handles.saveclose, 'Visible', 'on');
set(handles.removexp, 'Visible', 'on');
snobfit_data = get(timerfindall('Tag','snobfit_tim'),'UserData');
data=snobfit_data.conditions
set(handles.doeuitable, 'Data',data, 'ColumnFormat',{'numeric'});
set(handles.doeuitable,'ColumnEditable',true)
% h = uitable('Data', dat, 'ColumnFormat', {'numeric'});
% close(h);
guidata(hObject, handles);

% --- Executes on button press in addrow.
function addrow_Callback(hObject, eventdata, handles)
snobfit_data = get(timerfindall('Tag','snobfit_tim'),'UserData');
data=snobfit_data.conditions
col_size = size(data, 2);
zero_row = zeros(1, col_size);
data=[data; zero_row]
set(handles.doeuitable, 'Data',data, 'ColumnFormat',{'numeric'});
set(handles.doeuitable,'ColumnEditable',true)

newconds=get(handles.doeuitable);
newconds=newconds.Data;
snobfit_data = get(timerfindall('Tag','snobfit_tim'),'UserData');
snobfit_data.conditions=newconds;
set(timerfindall('Tag','snobfit_tim'),'UserData',snobfit_data);

% --- Executes on button press in saveclose.
function saveclose_Callback(hObject, eventdata, handles)
set(handles.doeuitable, 'Visible', 'off');
set(handles.addrow, 'Visible', 'off');
set(handles.saveclose, 'Visible', 'off');
set(handles.removexp, 'Visible', 'off');
snobfit_data = get(timerfindall('Tag','snobfit_tim'),'UserData');
oldconditions=get(handles.conditionsText,'String');

newconds=get(handles.doeuitable)
newconds=newconds.Data
snobfit_data = get(timerfindall('Tag','snobfit_tim'),'UserData');
snobfit_data.conditions=newconds
set(timerfindall('Tag','snobfit_tim'),'UserData',snobfit_data)
timestamp = fix(clock);
timestamp = num2str(timestamp);
timestamp=strcat('Table edit at:   ',timestamp);
   newconds=num2str(newconds);
    combinedconds=strvcat(oldconditions, timestamp, newconds);
    set(handles.conditionsText,'String',combinedconds)% (gnc) print conditions to snobfit gui
    filename=strcat(handles.path,'\textlognotes.txt')
    textlog=get(handles.conditionsText,'String');
    
    oldconditions=get(handles.conditionsText,'String');
 CellArray = strcat(oldconditions); 
    fid = fopen(handles.logfile3,'w');
    for r=1:size(CellArray,1)
        fprintf(fid,'%s\n',CellArray(r,:));
    end
    fclose(fid);

% --- Executes on button press in removexp.
function removexp_Callback(hObject, eventdata, handles)
% hObject    handle to removexp (see GCBO)
snobfit_data = get(timerfindall('Tag','snobfit_tim'),'UserData');
data=snobfit_data.conditions
col_size = size(data, 2);
zero_row = zeros(1, col_size);
data=data((1:end-1),:);
set(handles.doeuitable, 'Data',data, 'ColumnFormat',{'numeric'});
set(handles.doeuitable,'ColumnEditable',true)
newconds=get(handles.doeuitable);
newconds=newconds.Data;
snobfit_data = get(timerfindall('Tag','snobfit_tim'),'UserData');
snobfit_data.conditions=newconds;
set(timerfindall('Tag','snobfit_tim'),'UserData',snobfit_data);

%restart timer callback
function restarttimercallback(obj, event)
%this is simply to make the simplextimer restart itself (no calculations
%needed)

start(timerfindall('Tag','simplextimer'))

function minRetentionTime_Callback(hObject, eventdata, handles)
checkNumericCallback(hObject, eventdata, handles)

% --- Executes during object creation, after setting all properties.
function minRetentionTime_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject, 'BackgroundColor'), get(0, 'defaultUicontrolBackgroundColor'))
    set(hObject, 'BackgroundColor', 'white');
end

function methodTime_Callback(hObject, eventdata, handles)
checkNumericCallback(hObject, eventdata, handles)

% --- Executes during object creation, after setting all properties.
function methodTime_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject, 'BackgroundColor'), get(0, 'defaultUicontrolBackgroundColor'))
    set(hObject, 'BackgroundColor', 'white');
end

% --- Designed to be run by all of the initial edit boxes to prevent text entry
function checkNumericCallback(callingObject, eventdata, handles)
% callingObject handle to the calling object

% handles       structure with handles and user data (see GUIDATA)

% parses contents
newNumber = str2double(get(callingObject, 'String'));

% checks contents to see if they are numeric, finite and real
if isnan(newNumber) || ~isfinite(newNumber) || ~isreal(newNumber)
    errordlg('Must enter a finite real number')
    set(callingObject, 'String', '')
end

% Update handles structure
guidata(callingObject, handles);

% --- Designed to be run by all of the min and max edit boxes
function checkMinMaxCallback(callingObject, eventdata, handles)
% callingObject handle to the calling object

% handles       structure with handles and user data (see GUIDATA)

% fetches the tag of the handle (the actual handle is a horribly unreadable
% number like 27.0023)
callingHandleString = get(callingObject, 'Tag');

% get the type (min or max) and object number from the tag
boxType = callingHandleString(isstrprop(callingHandleString, 'alpha'));
objectNumber = str2double(callingHandleString(isstrprop...
    (callingHandleString, 'digit')));

% parses contents
newNumber = str2double(get(callingObject, 'String'));

% get the link matrix
linked = getappdata(handles.snobfitgui,'linked');

%find the linked objects for this object only
linked = find(linked(objectNumber,:));

% checks contents to see if they are numeric, finite, real, greater than
% or equal to 0, larger than the minimum and smaller than the maximum
if isnan(newNumber) || ~isfinite(newNumber) || ~isreal(newNumber) || newNumber < 0
    errordlg('Must enter a finite real number greater than 0.')
    if ~isempty(linked)
        %if there is a link can set the value in this box back to what ever
        %is in the other boxes
        set(callingObject, 'String', get(handles.(sprintf...
            ('%s%d', boxType, linked(1))), 'String'))
    else
        %if no link then not sure what to do...set to blank
        set(callingObject, 'String', '')
    end
else
    if ~isempty(linked)
        %if there is a link, then should set all the linked objects to the
        %same value
        for n = 1:size(linked,2)
            set(handles.(sprintf('%s%d', boxType, linked(n))),...
                'String', newNumber)
        end
    end
end
% Update handles structure
guidata(callingObject, handles);

% --- Designed to be run by all of the enable boxes
function enableCallback(callingObject, eventdata, handles)
% callingObject handle to the calling object

% handles       structure with handles and user data (see GUIDATA)

% fetches the tag of the handle (the actual handle is a horribly unreadable
% number like 27.0023)
callingHandleString = get(callingObject, 'Tag');

% extracts the numeric parts of the handle name (this 'number' is actually
% a string)
numberString = callingHandleString(isstrprop(callingHandleString, 'digit'));

% turns that into a number for convenience
number = str2double(numberString);

parent = get(callingObject, 'Parent'); %get handle to the optimise GUI

%get the linked status
linked = getappdata(parent,'linked');

% pre-allocates matrix for loop
enableValue = zeros(8, 1);

% fetches the value from all of the enable boxes
for m = 1:8
    enableValue(m) = get(handles.(sprintf('checkbox%d' ,m)), 'Value');
end

% test if this object is enabled and sets defaults for use below
if enableValue(number)
    enableProperty = 'on';
    backgroundColour = [1, 1, 1];
else
    enableProperty = 'off';
    backgroundColour = [0.753, 0.753, 0.753];
    %this is for dealing with the linked state, if its not enabled can't be
    %linked to anything
    linked(number,1:end) = 0;
    linked(1:end,number) = 0;
end

%set the linked status
setappdata(parent,'linked',linked);

%startup for check for links
enableValueLinked = enableValue;

%loop through each object checking the link status
for obj = 1:size(enableValueLinked,1)
    %check if still enabled
    if enableValueLinked(obj)
        %check for a link
        enableValueLinked(linked(obj,1:end)==1,1) = 0;
    end
end

%calculate the actual number of dimensions
dims = min(sum(enableValue),sum(enableValueLinked));

% updates the dimensions box
set(handles.dimensionsBox, 'String', int2str(dims))

% (de)activates max, min and dx settings for this object
set(handles.(['min', numberString]), 'Enable', enableProperty,...
    'BackgroundColor', backgroundColour)
set(handles.(['max', numberString]), 'Enable', enableProperty,...
    'BackgroundColor', backgroundColour)
set(handles.(['dx', numberString]), 'Enable', enableProperty,...
    'BackgroundColor', backgroundColour)

%run the function to check all the other issues with using links 
linkCheckCallback(callingObject, eventdata, handles);

% Update handles structure
guidata(callingObject, handles);

% --- Designed to be run after enable callback and the linkGUI
function linkCheckCallback(callingObject, eventdata, handles)
% callingObject handle to the calling object

% handles       structure with handles and user data (see GUIDATA)

%get the linked status
linked = getappdata(handles.snobfitgui,'linked');

% pre-allocates matrix for loop
enableValue = zeros(1, 8);

% fetches the value from all of the enable boxes
for obj = 1:8
    enableValue(1,obj) = get(handles.(sprintf('checkbox%d' ,obj)), 'Value');
end

%recalc the dimensions
for obj = 1:8
    %check that this object is still enabled
    if enableValue(obj)
        %find which objects this object is linked to (if any) and
        %remove from enabled list as no longer really optimising this
        %object
        enableValue(linked(obj,:)==1)=0;
    end
end
dims = sum(enableValue);
set(handles.dimensionsBox,'String',dims);

%loop through each object to make sure all the values which should be
%linked are
for obj = 1:8
    if enableValue(obj)
        enableProperty = 'on';
        backgroundColour = [1, 1, 1];
        %check for links in this object
        linkobjs = find(linked(obj,:));
        %if there are any links then need to make sure that all the
        %values are the same
        if ~isempty(linkobjs)
            for n = 1:size(linkobjs,2)
                linkedObjectNumber = linkobjs(n);
                
                %set all the min, max, dx values to be the same
                set(handles.(sprintf('min%d',linkedObjectNumber)),...
                    'String', get(handles.(sprintf('min%d',obj)),'String'))
                set(handles.(sprintf('max%d',linkedObjectNumber)),...
                    'String', get(handles.(sprintf('max%d',obj)),'String'))
                set(handles.(sprintf('dx%d',linkedObjectNumber)),...
                    'String', get(handles.(sprintf('dx%d',obj)),'String'))
            end
        end
    else
        enableProperty = 'off';
        backgroundColour = [0.753, 0.753, 0.753];
    end
    
    % (de)activates max, min, dx for this object
    set(handles.(sprintf('min%d',obj)), 'Enable',...
        enableProperty, 'BackgroundColor', backgroundColour)
    set(handles.(sprintf('max%d',obj)), 'Enable',...
        enableProperty, 'BackgroundColor', backgroundColour)
    set(handles.(sprintf('dx%d',obj)), 'Enable',...
        enableProperty, 'BackgroundColor', backgroundColour)
end
% Update handles structure
guidata(callingObject, handles);

% --- Outputs from this function are returned to the command line.
function varargout = snobfitguiUV_OutputFcn(hObject, eventdata, handles)
varargout{1} = handles.output;

% --- Executes during object creation, after setting all properties.
function dimensionsBox_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject, 'BackgroundColor'), get(0, 'defaultUicontrolBackgroundColor'))
    set(hObject, 'BackgroundColor', 'white');
end

function iterationsBox_Callback(hObject, eventdata, handles)
% checks contents to see if they are numeric
checkNumericCallback(hObject, eventdata, handles)
% parses contents
newNumber = str2double(get(hObject, 'String'));
%need to make sure that number is at least 1
newNumber = max(1, newNumber);
%round number (towards inf.) as can't have fractional iterations
newNumber = ceil(newNumber);
% re-updates box
set(hObject, 'String', int2str(newNumber))
% Update handles structure
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function iterationsBox_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject, 'BackgroundColor'), get(0, 'defaultUicontrolBackgroundColor'))
    set(hObject, 'BackgroundColor', 'white');
end

function pBox_Callback(hObject, eventdata, handles)
checkNumericCallback(hObject, eventdata, handles)

% --- Executes during object creation, after setting all properties.
function pBox_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject, 'BackgroundColor'), get(0, 'defaultUicontrolBackgroundColor'))
    set(hObject, 'BackgroundColor', 'white');
end

% --- Executes on button press in savetext.
function savetext_Callback(hObject, eventdata, handles)
oldconditions=get(handles.conditionsText,'String');
 CellArray = strcat(oldconditions); 
    fid = fopen(handles.logfile3,'w');
    for r=1:size(CellArray,1)
        fprintf(fid,'%s\n',CellArray(r,:));
    end

% --- Executes on button press in pushbutton30.
function pushbutton30_Callback(hObject, eventdata, handles)
edit snobfitguiUV.m
hEditor = matlab.desktop.editor.getActive;
hEditor.goToLine(3693)

function ScndInjTim_Callback(hObject, eventdata, handles)

% --- Executes during object creation, after setting all properties.
function ScndInjTim_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function text63_CreateFcn(hObject, eventdata, handles)


    
% --- Executes during object creation, after setting all properties.
function checkbox1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to checkbox1 (see GCBO)

% --- Executes during object creation, after setting all properties.
function checkbox2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to checkbox2 (see GCBO)

% --- Executes during object creation, after setting all properties.
function checkbox3_CreateFcn(hObject, eventdata, handles)
% hObject    handle to checkbox3 (see GCBO)

% --- Executes during object creation, after setting all properties.
function checkbox6_CreateFcn(hObject, eventdata, handles)
% hObject    handle to checkbox6 (see GCBO)




% --- Callbacks for 8 optimisation variables

function flowratio1_Callback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function flowratio1_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function flowratio2_Callback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function flowratio2_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function flowratio3_Callback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function flowratio3_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function flowratio4_Callback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function flowratio4_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function flowratio5_Callback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function flowratio5_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function flowratio6_Callback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function flowratio6_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function flowratio7_Callback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function flowratio7_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function flowratio8_Callback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function flowratio8_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function FRobj1_Callback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function FRobj1_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function FRobj2_Callback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function FRobj2_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function FRobj3_Callback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function FRobj3_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function FRobj4_Callback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function FRobj4_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function FRobj5_Callback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function FRobj5_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function FRobj6_Callback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function FRobj6_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function FRobj7_Callback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function FRobj7_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function FRobj8_Callback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function FRobj8_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function min1_Callback(hObject, eventdata, handles)
checkMinMaxCallback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function min1_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject, 'BackgroundColor'), get(0, 'defaultUicontrolBackgroundColor'))
    set(hObject, 'BackgroundColor', 'white');
end

function min2_Callback(hObject, eventdata, handles)
checkMinMaxCallback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function min2_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject, 'BackgroundColor'), get(0, 'defaultUicontrolBackgroundColor'))
    set(hObject, 'BackgroundColor', 'white');
end

function min3_Callback(hObject, eventdata, handles)
checkMinMaxCallback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function min3_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject, 'BackgroundColor'), get(0, 'defaultUicontrolBackgroundColor'))
    set(hObject, 'BackgroundColor', 'white');
end

function min4_Callback(hObject, eventdata, handles)
checkMinMaxCallback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function min4_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject, 'BackgroundColor'), get(0, 'defaultUicontrolBackgroundColor'))
    set(hObject, 'BackgroundColor', 'white');
end

function min5_Callback(hObject, eventdata, handles)
checkMinMaxCallback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function min5_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject, 'BackgroundColor'), get(0, 'defaultUicontrolBackgroundColor'))
    set(hObject, 'BackgroundColor', 'white');
end

function min6_Callback(hObject, eventdata, handles)
checkMinMaxCallback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function min6_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject, 'BackgroundColor'), get(0, 'defaultUicontrolBackgroundColor'))
    set(hObject, 'BackgroundColor', 'white');
end

function min7_Callback(hObject, eventdata, handles)
checkMinMaxCallback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function min7_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject, 'BackgroundColor'), get(0, 'defaultUicontrolBackgroundColor'))
    set(hObject, 'BackgroundColor', 'white');
end

function min8_Callback(hObject, eventdata, handles)
checkMinMaxCallback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function min8_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject, 'BackgroundColor'), get(0, 'defaultUicontrolBackgroundColor'))
    set(hObject, 'BackgroundColor', 'white');
end



function max1_Callback(hObject, eventdata, handles)
checkMinMaxCallback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function max1_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject, 'BackgroundColor'), get(0, 'defaultUicontrolBackgroundColor'))
    set(hObject, 'BackgroundColor', 'white');
end

function max2_Callback(hObject, eventdata, handles)
checkMinMaxCallback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function max2_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject, 'BackgroundColor'), get(0, 'defaultUicontrolBackgroundColor'))
    set(hObject, 'BackgroundColor', 'white');
end

function max3_Callback(hObject, eventdata, handles)
checkMinMaxCallback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function max3_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject, 'BackgroundColor'), get(0, 'defaultUicontrolBackgroundColor'))
    set(hObject, 'BackgroundColor', 'white');
end

function max4_Callback(hObject, eventdata, handles)
checkMinMaxCallback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function max4_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject, 'BackgroundColor'), get(0, 'defaultUicontrolBackgroundColor'))
    set(hObject, 'BackgroundColor', 'white');
end

function max5_Callback(hObject, eventdata, handles)
checkMinMaxCallback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function max5_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject, 'BackgroundColor'), get(0, 'defaultUicontrolBackgroundColor'))
    set(hObject, 'BackgroundColor', 'white');
end

function max6_Callback(hObject, eventdata, handles)
checkMinMaxCallback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function max6_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject, 'BackgroundColor'), get(0, 'defaultUicontrolBackgroundColor'))
    set(hObject, 'BackgroundColor', 'white');
end

function max7_Callback(hObject, eventdata, handles)
checkMinMaxCallback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function max7_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject, 'BackgroundColor'), get(0, 'defaultUicontrolBackgroundColor'))
    set(hObject, 'BackgroundColor', 'white');
end

function max8_Callback(hObject, eventdata, handles)
checkMinMaxCallback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function max8_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject, 'BackgroundColor'), get(0, 'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor', 'white');
end



function dx1_Callback(hObject, eventdata, handles)
checkMinMaxCallback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function dx1_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject, 'BackgroundColor'), get(0, 'defaultUicontrolBackgroundColor'))
    set(hObject, 'BackgroundColor', 'white');
end

function dx2_Callback(hObject, eventdata, handles)
checkMinMaxCallback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function dx2_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject, 'BackgroundColor'), get(0, 'defaultUicontrolBackgroundColor'))
    set(hObject, 'BackgroundColor', 'white');
end

function dx3_Callback(hObject, eventdata, handles)
checkMinMaxCallback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function dx3_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject, 'BackgroundColor'), get(0, 'defaultUicontrolBackgroundColor'))
    set(hObject, 'BackgroundColor', 'white');
end

function dx4_Callback(hObject, eventdata, handles)
checkMinMaxCallback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function dx4_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject, 'BackgroundColor'), get(0, 'defaultUicontrolBackgroundColor'))
    set(hObject, 'BackgroundColor', 'white');
end

function dx5_Callback(hObject, eventdata, handles)
checkMinMaxCallback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function dx5_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject, 'BackgroundColor'), get(0, 'defaultUicontrolBackgroundColor'))
    set(hObject, 'BackgroundColor', 'white');
end

function dx6_Callback(hObject, eventdata, handles)
checkMinMaxCallback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function dx6_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject, 'BackgroundColor'), get(0, 'defaultUicontrolBackgroundColor'))
    set(hObject, 'BackgroundColor', 'white');
end

function dx7_Callback(hObject, eventdata, handles)
checkMinMaxCallback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function dx7_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject, 'BackgroundColor'), get(0, 'defaultUicontrolBackgroundColor'))
    set(hObject, 'BackgroundColor', 'white');
end

function dx8_Callback(hObject, eventdata, handles)
checkMinMaxCallback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function dx8_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function quench1_Callback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function quench1_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function quench2_Callback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function quench2_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function quench3_Callback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function quench3_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function quench4_Callback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function quench4_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function quench5_Callback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function quench5_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function quench6_Callback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.    
function quench6_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function quench7_Callback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function quench7_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function quench8_Callback(hObject, eventdata, handles)
% --- Executes during object creation, after setting all properties.
function quench8_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



% --- Executes on button press in rest1.
function rest1_Callback(hObject, eventdata, handles)
% --- Executes on button press in rest2.
function rest2_Callback(hObject, eventdata, handles)
% --- Executes on button press in rest3.
function rest3_Callback(hObject, eventdata, handles)
% --- Executes on button press in rest4.
function rest4_Callback(hObject, eventdata, handles)
% --- Executes on button press in rest5.
function rest5_Callback(hObject, eventdata, handles)
% --- Executes on button press in rest6.
function rest6_Callback(hObject, eventdata, handles)
% --- Executes on button press in rest7.
function rest7_Callback(hObject, eventdata, handles)
% --- Executes on button press in rest8.
function rest8_Callback(hObject, eventdata, handles)




% --- Executes on button press in checkbox1.
function checkbox1_Callback(hObject, eventdata, handles)
enableCallback(hObject, eventdata, handles)

% --- Executes on button press in checkbox2.
function checkbox2_Callback(hObject, eventdata, handles)
enableCallback(hObject, eventdata, handles)

% --- Executes on button press in checkbox3.
function checkbox3_Callback(hObject, eventdata, handles)
enableCallback(hObject, eventdata, handles)

% --- Executes on button press in checkbox4.
function checkbox4_Callback(hObject, eventdata, handles)
enableCallback(hObject, eventdata, handles)

% --- Executes on button press in checkbox5.
function checkbox5_Callback(hObject, eventdata, handles)
enableCallback(hObject, eventdata, handles)

% --- Executes on button press in checkbox6.
function checkbox6_Callback(hObject, eventdata, handles)
enableCallback(hObject, eventdata, handles)

% --- Executes on button press in checkbox7.
function checkbox7_Callback(hObject, eventdata, handles)
enableCallback(hObject, eventdata, handles)

% --- Executes on button press in checkbox8.
function checkbox8_Callback(hObject, eventdata, handles)
enableCallback(hObject, eventdata, handles)
   


% --- Executes during object creation, after setting all properties.
function objectLabel_CreateFcn(hObject, eventdata, handles)
% hObject    handle to objectLabel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function checkbox4_CreateFcn(hObject, eventdata, handles)
% hObject    handle to checkbox4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function checkbox5_CreateFcn(hObject, eventdata, handles)
% hObject    handle to checkbox5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function checkbox7_CreateFcn(hObject, eventdata, handles)
% hObject    handle to checkbox7 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function checkbox8_CreateFcn(hObject, eventdata, handles)
% hObject    handle to checkbox8 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function initialLabel_CreateFcn(hObject, eventdata, handles)
% hObject    handle to initialLabel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function iterationsLabel_CreateFcn(hObject, eventdata, handles)
% hObject    handle to iterationsLabel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function changeLabel_CreateFcn(hObject, eventdata, handles)
% hObject    handle to changeLabel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function start_CreateFcn(hObject, eventdata, handles)
% hObject    handle to start (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function name1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to name1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function name2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to name2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function name3_CreateFcn(hObject, eventdata, handles)
% hObject    handle to name3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function name4_CreateFcn(hObject, eventdata, handles)
% hObject    handle to name4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function name5_CreateFcn(hObject, eventdata, handles)
% hObject    handle to name5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function name6_CreateFcn(hObject, eventdata, handles)
% hObject    handle to name6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function name8_CreateFcn(hObject, eventdata, handles)
% hObject    handle to name8 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function name7_CreateFcn(hObject, eventdata, handles)
% hObject    handle to name7 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function status0_CreateFcn(hObject, eventdata, handles)
% hObject    handle to status0 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function status1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to status1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function text54_CreateFcn(hObject, eventdata, handles)
% hObject    handle to text54 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function text58_CreateFcn(hObject, eventdata, handles)
% hObject    handle to text58 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function ratiobox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ratiobox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function rest1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to rest1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function rest2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to rest2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function rest3_CreateFcn(hObject, eventdata, handles)
% hObject    handle to rest3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function rest4_CreateFcn(hObject, eventdata, handles)
% hObject    handle to rest4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function rest5_CreateFcn(hObject, eventdata, handles)
% hObject    handle to rest5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function rest6_CreateFcn(hObject, eventdata, handles)
% hObject    handle to rest6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function rest7_CreateFcn(hObject, eventdata, handles)
% hObject    handle to rest7 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function rest8_CreateFcn(hObject, eventdata, handles)
% hObject    handle to rest8 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function text77_CreateFcn(hObject, eventdata, handles)
% hObject    handle to text77 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function text80_CreateFcn(hObject, eventdata, handles)
% hObject    handle to text80 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function pushbutton30_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pushbutton30 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called



function conditionsText_Callback(hObject, eventdata, handles)
% hObject    handle to conditionsText (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of conditionsText as text
%        str2double(get(hObject,'String')) returns contents of conditionsText as a double


% --- Executes during object creation, after setting all properties.
function maxRetentionTimeLabel_CreateFcn(hObject, eventdata, handles)
% hObject    handle to maxRetentionTimeLabel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function minRetentionTimeLabel_CreateFcn(hObject, eventdata, handles)
% hObject    handle to minRetentionTimeLabel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function methodTimeLabel_CreateFcn(hObject, eventdata, handles)
% hObject    handle to methodTimeLabel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function altGCcheck_CreateFcn(hObject, eventdata, handles)
% hObject    handle to altGCcheck (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function viewButton_CreateFcn(hObject, eventdata, handles)
% hObject    handle to viewButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function text47_CreateFcn(hObject, eventdata, handles)
% hObject    handle to text47 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function status2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to status2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function waiting_time_CreateFcn(hObject, eventdata, handles)
% hObject    handle to waiting_time (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function text57_CreateFcn(hObject, eventdata, handles)
% hObject    handle to text57 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function text59_CreateFcn(hObject, eventdata, handles)
% hObject    handle to text59 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function hplcstartdelaytext_CreateFcn(hObject, eventdata, handles)
% hObject    handle to hplcstartdelaytext (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function text61_CreateFcn(hObject, eventdata, handles)
% hObject    handle to text61 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function text55_CreateFcn(hObject, eventdata, handles)
% hObject    handle to text55 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function pauseopt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pauseopt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function conditionsText_CreateFcn(hObject, eventdata, handles)
% hObject    handle to conditionsText (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function text65_CreateFcn(hObject, eventdata, handles)
% hObject    handle to text65 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function text67_CreateFcn(hObject, eventdata, handles)
% hObject    handle to text67 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function OvernightCB_CreateFcn(hObject, eventdata, handles)
% hObject    handle to OvernightCB (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function picotestCB_CreateFcn(hObject, eventdata, handles)
% hObject    handle to picotestCB (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function Plotsnob_but_CreateFcn(hObject, eventdata, handles)
% hObject    handle to Plotsnob_but (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function text68_CreateFcn(hObject, eventdata, handles)
% hObject    handle to text68 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function text69_CreateFcn(hObject, eventdata, handles)
% hObject    handle to text69 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function text70_CreateFcn(hObject, eventdata, handles)
% hObject    handle to text70 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function status3_CreateFcn(hObject, eventdata, handles)
% hObject    handle to status3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function status4_CreateFcn(hObject, eventdata, handles)
% hObject    handle to status4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function DOEbox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to DOEbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function text75_CreateFcn(hObject, eventdata, handles)
% hObject    handle to text75 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function editdoe_CreateFcn(hObject, eventdata, handles)
% hObject    handle to editdoe (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function addrow_CreateFcn(hObject, eventdata, handles)
% hObject    handle to addrow (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function saveclose_CreateFcn(hObject, eventdata, handles)
% hObject    handle to saveclose (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function removexp_CreateFcn(hObject, eventdata, handles)
% hObject    handle to removexp (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function savetext_CreateFcn(hObject, eventdata, handles)
% hObject    handle to savetext (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function text81_CreateFcn(hObject, eventdata, handles)
% hObject    handle to text81 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
