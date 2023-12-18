classdef FUSPlan_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                    matlab.ui.Figure
        MainLayout                  matlab.ui.container.GridLayout
        TabGroup                    matlab.ui.container.TabGroup
        LoadTab                     matlab.ui.container.Tab
        LoadLayout                  matlab.ui.container.GridLayout
        SessionIDField              matlab.ui.control.EditField
        SessionIDLabel              matlab.ui.control.Label
        SubjectIDField              matlab.ui.control.EditField
        SubjectIDLabel              matlab.ui.control.Label
        SessionNameField            matlab.ui.control.EditField
        SubjectNameField            matlab.ui.control.EditField
        SessionNameLabel            matlab.ui.control.Label
        SubjectNameLabel            matlab.ui.control.Label
        LoadSessionButton           matlab.ui.control.Button
        ReviewTab                   matlab.ui.container.Tab
        ReviewTabLayout             matlab.ui.container.GridLayout
        ReviewPanel                 matlab.ui.container.Panel
        ReviewLayout                matlab.ui.container.GridLayout
        GridLayout2                 matlab.ui.container.GridLayout
        GoToOriginButton            matlab.ui.control.Button
        GoToTargetButton            matlab.ui.control.Button
        GoToLabel                   matlab.ui.control.Label
        SelectedVoxelTable          matlab.ui.control.Table
        ViewDropDown                matlab.ui.control.DropDown
        ViewLabel                   matlab.ui.control.Label
        PerspectiveDropDown         matlab.ui.control.DropDown
        PerspectiveLabel            matlab.ui.control.Label
        LayerDropDown               matlab.ui.control.DropDown
        LayerSettingsLabel          matlab.ui.control.Label
        CMapLayout                  matlab.ui.container.GridLayout
        GridLayout                  matlab.ui.container.GridLayout
        CMinAutoButton              matlab.ui.control.Button
        CMaxAutoButton              matlab.ui.control.Button
        CMapRangeMin                matlab.ui.control.NumericEditField
        CMapRangeMax                matlab.ui.control.NumericEditField
        CMapAxes                    matlab.ui.control.UIAxes
        PlanTab                     matlab.ui.container.Tab
        PlanTabLayout               matlab.ui.container.GridLayout
        PlanPanel                   matlab.ui.container.Panel
        PlanLayout                  matlab.ui.container.GridLayout
        TargetDropDown              matlab.ui.control.DropDown
        GridLayout3                 matlab.ui.container.GridLayout
        PlanDropDown                matlab.ui.control.DropDown
        TargetOKLamp                matlab.ui.control.Lamp
        SolutionTable               matlab.ui.control.Table
        SolutionLabel               matlab.ui.control.Label
        SelectTargetLabel           matlab.ui.control.Label
        PlanTable                   matlab.ui.control.Table
        TreatmentPlanSettingsLabel  matlab.ui.control.Label
        PlanTreatmentButton         matlab.ui.control.Button
        SelectPlanLabel             matlab.ui.control.Label
        TreatTab                    matlab.ui.container.Tab
        TreatTabLayout              matlab.ui.container.GridLayout
        TreatPanel                  matlab.ui.container.Panel
        TreatLayout                 matlab.ui.container.GridLayout
        SystemTable                 matlab.ui.control.Table
        SystemDropDown              matlab.ui.control.DropDown
        TreatmentSystemLabel        matlab.ui.control.Label
        StartTreatmentButton        matlab.ui.control.Button
        AxesLayout                  matlab.ui.container.GridLayout
        UIAxes3D                    matlab.ui.control.UIAxes
        UIAxesXY                    matlab.ui.control.UIAxes
        UIAxesXZ                    matlab.ui.control.UIAxes
        UIAxesYZ                    matlab.ui.control.UIAxes
    end

    properties (Access = private)
        db fus.Database % Database
        log fus.util.Logger
        subject fus.Subject
        session fus.Session
        cmaps fus.ColorMapper
        axes
        scenes struct
        values struct = struct()
        sim_scenes struct
        scene fus.Scene
        plans fus.treatment.Plan
        solutions struct = struct()
        output struct = struct()
        plan_id (1,1) string
        target_id (1,1) string
        view_id (1,1) string = "mri"
        layer_id (1,1) string
        system fus.sys.UltrasoundSystem = fus.sys.NoSystem
        perspective_id (1,1) string = "head"
        available_scenes (1,:) fus.Scene
        layer_ranges = struct("mri", [], "pnp", [], "ita", [])
    end
    
    properties (Access = public)
         fourup fus.ui.FourUp
         cmap_ui fus.ui.ColorMapper_UI
    end
    
    methods (Access = public)        
        function update_table(app)
            nrows = 7;
            tab = app.fourup.get_table();
            tab = cell2table([tab.Properties.VariableNames;table2cell(tab)]);
            if size(tab,1) < nrows
                tab = [tab;repmat({'','',''},nrows-size(tab,1),1)];
            end
            app.SelectedVoxelTable.Data = tab;
            app.SelectedVoxelTable.ColumnName = {};
            s = uistyle('FontWeight', 'Bold', 'BackgroundColor', 'k');
            addStyle(app.SelectedVoxelTable,s,'row',1)
            app.values.(app.plan_id).(app.target_id).(app.perspective_id) = app.fourup.values;
        end
    end
    
    methods (Access = private)
        
        function load_scene(app)
            new_scene = app.available_scenes.by_id(app.view_id);
            if app.scene == new_scene
                return
            end
            if isfield(app.values, app.plan_id) && ...
                isfield(app.values.(app.plan_id), app.target_id) && ...
                isfield(app.values.(app.plan_id).(app.target_id), app.perspective_id)
                init_values = app.values.(app.plan_id).(app.target_id).(app.perspective_id);
            else
                init_values = [];
            end
            app.scene = new_scene;
            f = app.scene.four_up(...
                "axes", app.axes, ...
                "values", init_values, ...
                "on_update", @app.update_table);
            app.fourup = f;
            set(app.LayerDropDown, ...
                "Items", [app.scene.volumes.name], ...
                "ItemsData", [app.scene.colormaps.id])
            if ~ismember(app.layer_id, [app.scene.colormaps.id])
                app.set_layer(app.scene.colormaps(1).id);
            else
                app.set_layer(app.layer_id);
            end
            app.cmap_ui.on_update = @f.update_images;
            app.update_table();
        end
        
        function load_session(app, subject_id, session_id)
            new_subject = app.db.load_subject(subject_id);
            if isempty(new_subject)
                return
            end
            app.subject = new_subject;
            new_session = app.db.load_session(app.subject, session_id);
            if isempty(new_session)
                return
            end
            app.session = new_session;
            app.SubjectNameField.Value = app.subject.name;
            app.SubjectIDField.Value = app.subject.id;
            app.SessionNameField.Value = app.session.name;
            app.SessionIDField.Value = app.session.id;
            data = app.db.load_session_solutions(app.session, ...
                "plans", app.plans, ...
                "figure", app.UIFigure, ...
                "progressbar", true);
            app.scenes = data.scenes;
            app.sim_scenes = data.sim_scenes;
            app.solutions = data.solutions;
            app.output = data.output;
            app.plan_id = data.most_recent.plan_id;
            app.cmaps = data.cmaps;
            plan_ids = [app.plans.id];
            set(app.PlanDropDown, ...
                "Items", [app.plans.name], ...
                "ItemsData", plan_ids, ...
                "Value", app.plan_id);  
            app.target_id = data.most_recent.target_id;
            target_ids =  [app.session.targets.id];
            set(app.TargetDropDown, ...
                "Items", [app.session.targets.name], ...
                "ItemsData", target_ids, ...
                "Value", app.target_id);    
            app.perspective_id = "head";
            app.view_id = "mri";
            app.update_available_views()
            app.update_plan_table()
            app.update_solution_table()
            app.layer_ranges = struct("mri", [], "pnp", [], "ita", []);
            app.load_scene();
            app.ReviewPanel.Enable = "on";
            app.PlanPanel.Enable = "on";
        end
        
        function set_cmap_range(app, range)
            range = sort(range);
            app.CMapRangeMax.Value = range(2);
            app.CMapRangeMin.Value = range(1);
            app.layer_ranges.(app.layer_id) = range;
            app.cmap_ui.set_range(range);
        end      
        
        function set_perspective(app, perspective_id)
            app.PerspectiveDropDown.Value = perspective_id;
            app.perspective_id = perspective_id;
            app.update_available_views()
            app.load_scene()
        end
        
        function set_plan(app, plan_id)
            app.PlanDropDown.Value = plan_id;
            app.plan_id = plan_id;
            app.update_available_views();
            app.update_plan_table();
            app.update_solution_table();
            app.load_scene()
        end
        
        function set_target(app, target_id)
            app.TargetDropDown.Value = target_id;
            app.target_id = target_id;
            app.update_available_views()
            app.update_solution_table();
            app.load_scene()
        end
        
        function set_view(app, view_id)
            app.ViewDropDown.Value = view_id;
            app.view_id = view_id;
            app.load_scene()
        end
        
        function set_layer(app, layer_id)
            app.LayerDropDown.Value = layer_id;
            app.layer_id = layer_id;
            f = app.fourup;
            cmap = app.scene.colormaps.by_id(app.layer_id);
            range = app.layer_ranges.(layer_id);
            app.cmap_ui = fus.ui.ColorMapper_UI(cmap, ...
                "axes", app.CMapAxes, ...
                "on_update", @f.update_images, ...
                "fg_color", [1,1,1], ...
                "bg_color", [0,0,0], ...
                "range", range, ...
                "label_side", "outside", ...
                "label_offset", 0.2);
            app.layer_ranges.(layer_id) = app.cmap_ui.range;
            app.CMapRangeMax.Value = app.layer_ranges.(layer_id)(2);
            app.CMapRangeMin.Value = app.layer_ranges.(layer_id)(1);
        end
        
        function set_system(app, sys_id)
            if sys_id == "none"
                app.system = fus.sys.NoSystem;
                app.StartTreatmentButton.Enable = "off";
            else
                app.system = app.db.load_system(sys_id);
                app.StartTreatmentButton.Enable = "on";
            end
            app.SystemDropDown.Value = sys_id;
            t = struct2table(app.system.info());
            c = [t.Properties.VariableNames', table2cell(t)'];
            app.SystemTable.Data = cell2table(c);
            app.TreatLayout.RowHeight{app.SystemTable.Layout.Row} = (app.SystemTable.FontSize+10)*size(c,1)+2;
            app.log.info("Set active system to %s", sys_id)
        end
        
        function set_available_systems(app, sys_ids)
            connected_ids = app.db.get_connected_systems();
            if isempty(connected_ids) || isempty(sys_ids)
                set(app.SystemDropDown, ...
                    "Items", "No System", ...
                    "ItemsData", "none", ...
                    "Value", "none", ...
                    "Enable", "off");
                app.set_system("none")
            else
                if any(~ismember(sys_ids, connected_ids))
                    app.log.throw_error("Invalid System ID. Connected Systems are %s", join(connected_ids, ","))
                end
                sys_info = app.db.get_system_info(sys_ids);
                if ismember(app.system.id, sys_ids)
                    sys_id = app.system.id;
                else
                    sys_id = sys_ids(1);
                end
                set(app.SystemDropDown, ...
                    "Items", string([sys_info.name]), ...
                    "ItemsData", string([sys_info.id]),...
                    "Value", sys_id, ...
                    "Enable", "on")
                if ~ismember(app.system.id, sys_ids)
                    app.set_system(sys_ids(1));
                end
            end
        end
        
        function plan_treatment(app)
            sim_scene = app.sim_scenes.(app.plan_id);
            plan = app.plans.by_id(app.plan_id);
            [solution, sim_output] = plan.calc_solution(sim_scene, "log", app.log, "target_id", app.target_id, "progressbar",true, "figure", app.UIFigure);
            view_ids = reshape(string(fieldnames(app.scenes.(app.plan_id).(app.target_id))), 1, []);
            for set_view_id = view_ids
                mri_scene = app.scenes.(app.plan_id).(app.target_id).(set_view_id)(1);
                new_scenes = solution.to_scenes(sim_output, mri_scene, "cmaps", app.cmaps, "adjust_cmaps", true);
                app.scenes.(app.plan_id).(app.target_id).(set_view_id) = [mri_scene, new_scenes];
            end
            
            if ~isfield(app.solutions, app.plan_id)
                app.solutions.(app.plan_id) = solution;
            else
                target_ids = [app.solutions.(app.plan_id).target_id];
                if ismember(app.target_id, target_ids)
                    solution_index = find(app.target_id == target_ids, 1);
                    app.solutions.(app.plan_id)(solution_index) = solution;
                else
                    app.solutions.(app.plan_id)(end+1) = solution;
                end
            end
            app.output.(app.plan_id).(app.target_id) = sim_output;
            app.db.add_solution(solution, app.subject.id, app.session.id, "output", sim_output, "on_conflict", "overwrite");
            app.update_available_views();
            app.update_solution_table();
            app.set_view("pnp");
            app.set_layer("pnp");
        end
        
        function update_available_views(app)
            app.available_scenes = app.scenes.(app.plan_id).(app.target_id).(app.perspective_id);
            if ~ismember(app.view_id, [app.available_scenes.id])
                app.view_id = app.available_scenes(1).id;
            end
            set(app.ViewDropDown, ...
                "Items", [app.available_scenes.name], ...
                "ItemsData", [app.available_scenes.id], ...
                "Value", app.view_id);
        end
        
        
        function update_plan_table(app)
            plan = app.plans.by_id(app.plan_id);
            tab = plan.get_table();
            tab = [tab.Properties.VariableNames; table2cell(tab)];
            app.PlanTable.Data = cell2table(tab);
            s = uistyle('FontWeight', 'Bold', 'BackgroundColor', 'k');
            addStyle(app.PlanTable, s,'row',1)
            app.PlanLayout.RowHeight{app.PlanTable.Layout.Row} = (app.PlanTable.FontSize+10)*size(tab,1)+2+20;
        end
                
        function update_solution_table(app)
            plan = app.plans.by_id(app.plan_id);
            sim_scene = app.sim_scenes.(app.plan_id);
            target = sim_scene.targets.by_id(app.target_id);
            target_check = plan.check_targets(target);
            if ~all([target_check.ok])
                app.TargetOKLamp.Color = [1,0,0];
                app.PlanTreatmentButton.Enable = "off";
                app.TreatPanel.Enable = "off";
                not_ok = find(~[target_check.ok]);
                tab = cell(length(not_ok),1);
                tab{1} = "Cannot Generate Solution";
                for i = 1:length(not_ok)
                     tab{i+1,1} = target_check(not_ok(i)).message;
                end
            else
                app.PlanTreatmentButton.Enable = "on";
                app.TargetOKLamp.Color = [0,1,0];
                nrows = 1;
                if isfield(app.solutions, app.plan_id) && ismember(app.target_id, [app.solutions.(app.plan_id).target_id])
                    solution_output = app.output.(app.plan_id).(app.target_id);
                    tab = app.solutions.(app.plan_id).by_target(app.target_id).get_table(solution_output.analysis, "agg", "max");  
                    tab = [tab.Properties.VariableNames; table2cell(tab)];
                    app.TreatPanel.Enable = "on";
                else
                    tab = num2cell(repmat("",nrows,3));
                    app.TreatPanel.Enable = "off";
                end
            end
            app.SolutionTable.Data = cell2table(tab);
            s = uistyle('FontWeight', 'Bold', 'BackgroundColor', 'k');
            addStyle(app.SolutionTable, s,'row',1)
            app.PlanLayout.RowHeight{app.SolutionTable.Layout.Row} = (app.SolutionTable.FontSize+10)*size(tab,1)+2;
        end
        

    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function Startup(app, options)
            % STARTUP Launch FUSPlan
            %   FUSPLAN("param",val...)
            %
            % Optional Parameters:
            %   'path': (string) db path
            %   'subject_id' (string) subject_id to skip selection
            %   'session_id' (string) session_id to skip selection
            %   'plan_ids' (1,:) string plan ids to allow
            %   'log' (Logger) system logger. 
            arguments
                app fus.ui.FUSPlan
                options.path (1,1) string {mustBeFolder} = fus.Database.get_default_path
                options.subject_id (1,1) string {mustBeValidVariableName}
                options.session_id (1,1) string {mustBeValidVariableName}
                options.plan_ids (1,:) string {mustBeValidVariableName}
                options.log fus.util.Logger = fus.util.Logger.get
            end
            here = fileparts(mfilename('fullpath'));
            repo_path = fileparts(fileparts(here));
            addpath(repo_path);
            app_icon_filename = fullfile(here, "icon_app.png");
            app.UIFigure.Icon = app_icon_filename;
            app.log = options.log;
            app.db = fus.Database("path", options.path, "log", app.log);
            if isfield(options, "plan_ids")
                app.plans = arrayfun(@(id)app.db.load_plan(id), reshape(options.plan_ids, 1, []));
            else
                app.plans = app.db.load_all_plans();
            end
            app.axes = [app.UIAxesYZ, app.UIAxesXZ, app.UIAxesXY, app.UIAxes3D];
            drawnow;
            if all(isfield(options, ["subject_id", "session_id"]))
                app.load_session(options.subject_id, options.session_id); 
            end
            connected_ids = app.db.get_connected_systems();
            app.set_available_systems(connected_ids);
        end

        % Button pushed function: LoadSessionButton
        function LoadSessionButtonPushed(app, event)
            subject_id = app.db.choose_subject("figure", app.UIFigure);
            if isempty(subject_id)
                return
            end
            load_subject = app.db.load_subject(subject_id);
            session_id = app.db.choose_session(load_subject, "figure", app.UIFigure);
            drawnow;
            if isempty(session_id)
                return
            end
            app.load_session(subject_id, session_id);
        end

        % Value changed function: ViewDropDown
        function ViewDropDownValueChanged(app, event)
            app.set_view(app.ViewDropDown.Value);
        end

        % Value changed function: LayerDropDown
        function LayerDropDownValueChanged(app, event)
            app.set_layer(app.LayerDropDown.Value);
        end

        % Value changed function: PerspectiveDropDown
        function PerspectiveDropDownValueChanged(app, event)
            app.set_perspective(app.PerspectiveDropDown.Value);
        end

        % Value changed function: PlanDropDown
        function PlanDropDownValueChanged(app, event)
            app.set_plan(app.PlanDropDown.Value);
        end

        % Value changed function: TargetDropDown
        function TargetDropDownValueChanged(app, event)
            app.set_target(app.TargetDropDown.Value);
        end

        % Button pushed function: PlanTreatmentButton
        function PlanTreatmentButtonPushed(app, event)
            app.plan_treatment();
        end

        % Value changed function: CMapRangeMax
        function CMapRangeMaxValueChanged(app, event)
            value = app.CMapRangeMax.Value;
            range = app.layer_ranges.(app.layer_id);
            if value > range(1)
                range(2) = value;
            end
            app.set_cmap_range(range)
        end

        % Value changed function: CMapRangeMin
        function CMapRangeMinValueChanged(app, event)
            value = app.CMapRangeMin.Value;
            range = app.layer_ranges.(app.layer_id);
            if value < range(2)
                range(1) = value;
            end
            app.set_cmap_range(range)
        end

        % Button pushed function: CMaxAutoButton
        function CMaxAutoButtonPushed(app, event)
            cmax = app.scene.volumes.by_id(app.layer_id).percentile(1);
            range = app.layer_ranges.(app.layer_id);
            range(2) = cmax;
            app.set_cmap_range(range);
        end

        % Button pushed function: CMinAutoButton
        function CMinAutoButtonPushed(app, event)
            cmin = app.scene.volumes.by_id(app.layer_id).percentile(0);
            range = app.layer_ranges.(app.layer_id);
            range(1) = cmin;
            app.set_cmap_range(range);
        end

        % Button pushed function: GoToTargetButton
        function GoToTargetButtonPushed(app, event)
            target = app.scene.targets.by_id(app.target_id);
            app.fourup.set_values(target.position)
        end

        % Button pushed function: GoToOriginButton
        function GoToOriginButtonPushed(app, event)
            coords = app.scene.volumes.get_coords;
            origin = cellfun(@mean, coords.extent);
            app.fourup.set_values(origin)
            app.fourup.reset_view()
        end

        % Button pushed function: StartTreatmentButton
        function StartTreatmentButtonPushed(app, event)
            solution = app.solutions.(app.plan_id).by_target(app.target_id);
            app.system.run(solution, "figure", app.UIFigure)
        end

        % Value changed function: SystemDropDown
        function SystemDropDownValueChanged(app, event)
            value = app.SystemDropDown.Value;
            app.set_system(value);
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1381 879];
            app.UIFigure.Name = 'FUSPlan - INVESTIGATIONAL USE ONLY';

            % Create MainLayout
            app.MainLayout = uigridlayout(app.UIFigure);
            app.MainLayout.ColumnWidth = {'1x', 250};
            app.MainLayout.RowHeight = {'1x'};
            app.MainLayout.BackgroundColor = [0 0 0];

            % Create AxesLayout
            app.AxesLayout = uigridlayout(app.MainLayout);
            app.AxesLayout.ColumnSpacing = 20;
            app.AxesLayout.RowSpacing = 40;
            app.AxesLayout.Padding = [40 40 10 10];
            app.AxesLayout.Layout.Row = 1;
            app.AxesLayout.Layout.Column = 1;
            app.AxesLayout.BackgroundColor = [0 0 0];

            % Create UIAxesYZ
            app.UIAxesYZ = uiaxes(app.AxesLayout);
            xlabel(app.UIAxesYZ, 'X')
            ylabel(app.UIAxesYZ, 'Y')
            zlabel(app.UIAxesYZ, 'Z')
            app.UIAxesYZ.FontWeight = 'bold';
            app.UIAxesYZ.XColor = [1 1 1];
            app.UIAxesYZ.YColor = [1 1 1];
            app.UIAxesYZ.ZColor = [1 1 1];
            app.UIAxesYZ.Color = [0 0 0];
            app.UIAxesYZ.FontSize = 14;
            app.UIAxesYZ.Box = 'on';
            app.UIAxesYZ.Layout.Row = 1;
            app.UIAxesYZ.Layout.Column = 1;

            % Create UIAxesXZ
            app.UIAxesXZ = uiaxes(app.AxesLayout);
            xlabel(app.UIAxesXZ, 'X')
            ylabel(app.UIAxesXZ, 'Y')
            zlabel(app.UIAxesXZ, 'Z')
            app.UIAxesXZ.FontWeight = 'bold';
            app.UIAxesXZ.XColor = [1 1 1];
            app.UIAxesXZ.YColor = [1 1 1];
            app.UIAxesXZ.ZColor = [1 1 1];
            app.UIAxesXZ.Color = [0 0 0];
            app.UIAxesXZ.FontSize = 14;
            app.UIAxesXZ.Box = 'on';
            app.UIAxesXZ.Layout.Row = 1;
            app.UIAxesXZ.Layout.Column = 2;

            % Create UIAxesXY
            app.UIAxesXY = uiaxes(app.AxesLayout);
            xlabel(app.UIAxesXY, 'X')
            ylabel(app.UIAxesXY, 'Y')
            zlabel(app.UIAxesXY, 'Z')
            app.UIAxesXY.FontWeight = 'bold';
            app.UIAxesXY.XColor = [1 1 1];
            app.UIAxesXY.YColor = [1 1 1];
            app.UIAxesXY.ZColor = [1 1 1];
            app.UIAxesXY.Color = [0 0 0];
            app.UIAxesXY.FontSize = 14;
            app.UIAxesXY.Box = 'on';
            app.UIAxesXY.Layout.Row = 2;
            app.UIAxesXY.Layout.Column = 1;

            % Create UIAxes3D
            app.UIAxes3D = uiaxes(app.AxesLayout);
            xlabel(app.UIAxes3D, 'X')
            ylabel(app.UIAxes3D, 'Y')
            zlabel(app.UIAxes3D, 'Z')
            app.UIAxes3D.FontWeight = 'bold';
            app.UIAxes3D.XColor = [1 1 1];
            app.UIAxes3D.YColor = [1 1 1];
            app.UIAxes3D.ZColor = [1 1 1];
            app.UIAxes3D.Color = [0 0 0];
            app.UIAxes3D.FontSize = 14;
            app.UIAxes3D.Box = 'on';
            app.UIAxes3D.Layout.Row = 2;
            app.UIAxes3D.Layout.Column = 2;

            % Create TabGroup
            app.TabGroup = uitabgroup(app.MainLayout);
            app.TabGroup.Layout.Row = 1;
            app.TabGroup.Layout.Column = 2;

            % Create LoadTab
            app.LoadTab = uitab(app.TabGroup);
            app.LoadTab.Title = 'Load';

            % Create LoadLayout
            app.LoadLayout = uigridlayout(app.LoadTab);
            app.LoadLayout.ColumnWidth = {'1x'};
            app.LoadLayout.RowHeight = {50, 20, 30, 20, 30, 20, 30, 20, 30};
            app.LoadLayout.BackgroundColor = [0 0 0];

            % Create LoadSessionButton
            app.LoadSessionButton = uibutton(app.LoadLayout, 'push');
            app.LoadSessionButton.ButtonPushedFcn = createCallbackFcn(app, @LoadSessionButtonPushed, true);
            app.LoadSessionButton.BackgroundColor = [0.149 0.149 0.149];
            app.LoadSessionButton.FontSize = 16;
            app.LoadSessionButton.FontWeight = 'bold';
            app.LoadSessionButton.FontColor = [1 1 1];
            app.LoadSessionButton.Layout.Row = 1;
            app.LoadSessionButton.Layout.Column = 1;
            app.LoadSessionButton.Text = 'Load Session';

            % Create SubjectNameLabel
            app.SubjectNameLabel = uilabel(app.LoadLayout);
            app.SubjectNameLabel.FontColor = [1 1 1];
            app.SubjectNameLabel.Layout.Row = 2;
            app.SubjectNameLabel.Layout.Column = 1;
            app.SubjectNameLabel.Text = 'Subject Name';

            % Create SessionNameLabel
            app.SessionNameLabel = uilabel(app.LoadLayout);
            app.SessionNameLabel.FontColor = [1 1 1];
            app.SessionNameLabel.Layout.Row = 6;
            app.SessionNameLabel.Layout.Column = 1;
            app.SessionNameLabel.Text = 'Session Name';

            % Create SubjectNameField
            app.SubjectNameField = uieditfield(app.LoadLayout, 'text');
            app.SubjectNameField.Editable = 'off';
            app.SubjectNameField.FontColor = [1 1 1];
            app.SubjectNameField.BackgroundColor = [0.149 0.149 0.149];
            app.SubjectNameField.Layout.Row = 3;
            app.SubjectNameField.Layout.Column = 1;

            % Create SessionNameField
            app.SessionNameField = uieditfield(app.LoadLayout, 'text');
            app.SessionNameField.Editable = 'off';
            app.SessionNameField.FontColor = [1 1 1];
            app.SessionNameField.BackgroundColor = [0.149 0.149 0.149];
            app.SessionNameField.Layout.Row = 7;
            app.SessionNameField.Layout.Column = 1;

            % Create SubjectIDLabel
            app.SubjectIDLabel = uilabel(app.LoadLayout);
            app.SubjectIDLabel.FontColor = [1 1 1];
            app.SubjectIDLabel.Layout.Row = 4;
            app.SubjectIDLabel.Layout.Column = 1;
            app.SubjectIDLabel.Text = 'Subject ID';

            % Create SubjectIDField
            app.SubjectIDField = uieditfield(app.LoadLayout, 'text');
            app.SubjectIDField.Editable = 'off';
            app.SubjectIDField.FontColor = [1 1 1];
            app.SubjectIDField.BackgroundColor = [0.149 0.149 0.149];
            app.SubjectIDField.Layout.Row = 5;
            app.SubjectIDField.Layout.Column = 1;

            % Create SessionIDLabel
            app.SessionIDLabel = uilabel(app.LoadLayout);
            app.SessionIDLabel.FontColor = [1 1 1];
            app.SessionIDLabel.Layout.Row = 8;
            app.SessionIDLabel.Layout.Column = 1;
            app.SessionIDLabel.Text = 'Session ID';

            % Create SessionIDField
            app.SessionIDField = uieditfield(app.LoadLayout, 'text');
            app.SessionIDField.Editable = 'off';
            app.SessionIDField.FontColor = [1 1 1];
            app.SessionIDField.BackgroundColor = [0.149 0.149 0.149];
            app.SessionIDField.Layout.Row = 9;
            app.SessionIDField.Layout.Column = 1;

            % Create ReviewTab
            app.ReviewTab = uitab(app.TabGroup);
            app.ReviewTab.Title = 'Review';

            % Create ReviewTabLayout
            app.ReviewTabLayout = uigridlayout(app.ReviewTab);
            app.ReviewTabLayout.ColumnWidth = {'1x'};
            app.ReviewTabLayout.RowHeight = {'1x'};
            app.ReviewTabLayout.Padding = [0 0 0 0];
            app.ReviewTabLayout.BackgroundColor = [0 0 0];

            % Create ReviewPanel
            app.ReviewPanel = uipanel(app.ReviewTabLayout);
            app.ReviewPanel.Enable = 'off';
            app.ReviewPanel.BorderType = 'none';
            app.ReviewPanel.BackgroundColor = [0 0 0];
            app.ReviewPanel.Layout.Row = 1;
            app.ReviewPanel.Layout.Column = 1;

            % Create ReviewLayout
            app.ReviewLayout = uigridlayout(app.ReviewPanel);
            app.ReviewLayout.ColumnWidth = {'1x'};
            app.ReviewLayout.RowHeight = {20, 30, 20, 30, 20, 30, '1x', 156, 20, 30};
            app.ReviewLayout.BackgroundColor = [0 0 0];

            % Create CMapLayout
            app.CMapLayout = uigridlayout(app.ReviewLayout);
            app.CMapLayout.ColumnWidth = {'1x', 90, 40, 70};
            app.CMapLayout.RowHeight = {'1x'};
            app.CMapLayout.ColumnSpacing = 0;
            app.CMapLayout.Padding = [0 0 0 0];
            app.CMapLayout.Layout.Row = 7;
            app.CMapLayout.Layout.Column = 1;
            app.CMapLayout.BackgroundColor = [0 0 0];

            % Create CMapAxes
            app.CMapAxes = uiaxes(app.CMapLayout);
            app.CMapAxes.XTick = [];
            app.CMapAxes.YTick = [];
            app.CMapAxes.Color = [0 0 0];
            app.CMapAxes.Layout.Row = 1;
            app.CMapAxes.Layout.Column = 2;

            % Create GridLayout
            app.GridLayout = uigridlayout(app.CMapLayout);
            app.GridLayout.ColumnWidth = {'1x'};
            app.GridLayout.RowHeight = {30, 20, '1x', 20, 30};
            app.GridLayout.Padding = [0 0 0 0];
            app.GridLayout.Layout.Row = 1;
            app.GridLayout.Layout.Column = 4;
            app.GridLayout.BackgroundColor = [0 0 0];

            % Create CMapRangeMax
            app.CMapRangeMax = uieditfield(app.GridLayout, 'numeric');
            app.CMapRangeMax.ValueDisplayFormat = '%0.4g';
            app.CMapRangeMax.ValueChangedFcn = createCallbackFcn(app, @CMapRangeMaxValueChanged, true);
            app.CMapRangeMax.FontColor = [1 1 1];
            app.CMapRangeMax.BackgroundColor = [0.149 0.149 0.149];
            app.CMapRangeMax.Layout.Row = 1;
            app.CMapRangeMax.Layout.Column = 1;

            % Create CMapRangeMin
            app.CMapRangeMin = uieditfield(app.GridLayout, 'numeric');
            app.CMapRangeMin.ValueDisplayFormat = '%0.4g';
            app.CMapRangeMin.ValueChangedFcn = createCallbackFcn(app, @CMapRangeMinValueChanged, true);
            app.CMapRangeMin.FontColor = [1 1 1];
            app.CMapRangeMin.BackgroundColor = [0.149 0.149 0.149];
            app.CMapRangeMin.Layout.Row = 5;
            app.CMapRangeMin.Layout.Column = 1;

            % Create CMaxAutoButton
            app.CMaxAutoButton = uibutton(app.GridLayout, 'push');
            app.CMaxAutoButton.ButtonPushedFcn = createCallbackFcn(app, @CMaxAutoButtonPushed, true);
            app.CMaxAutoButton.BackgroundColor = [0.149 0.149 0.149];
            app.CMaxAutoButton.FontColor = [0.9412 0.9412 0.9412];
            app.CMaxAutoButton.Layout.Row = 2;
            app.CMaxAutoButton.Layout.Column = 1;
            app.CMaxAutoButton.Text = 'Auto';

            % Create CMinAutoButton
            app.CMinAutoButton = uibutton(app.GridLayout, 'push');
            app.CMinAutoButton.ButtonPushedFcn = createCallbackFcn(app, @CMinAutoButtonPushed, true);
            app.CMinAutoButton.BackgroundColor = [0.149 0.149 0.149];
            app.CMinAutoButton.FontColor = [0.9412 0.9412 0.9412];
            app.CMinAutoButton.Layout.Row = 4;
            app.CMinAutoButton.Layout.Column = 1;
            app.CMinAutoButton.Text = 'Auto';

            % Create LayerSettingsLabel
            app.LayerSettingsLabel = uilabel(app.ReviewLayout);
            app.LayerSettingsLabel.FontColor = [1 1 1];
            app.LayerSettingsLabel.Layout.Row = 5;
            app.LayerSettingsLabel.Layout.Column = 1;
            app.LayerSettingsLabel.Text = 'Layer Settings';

            % Create LayerDropDown
            app.LayerDropDown = uidropdown(app.ReviewLayout);
            app.LayerDropDown.Items = {'Select Layer'};
            app.LayerDropDown.ValueChangedFcn = createCallbackFcn(app, @LayerDropDownValueChanged, true);
            app.LayerDropDown.FontSize = 14;
            app.LayerDropDown.FontWeight = 'bold';
            app.LayerDropDown.FontColor = [1 1 1];
            app.LayerDropDown.BackgroundColor = [0.149 0.149 0.149];
            app.LayerDropDown.Layout.Row = 6;
            app.LayerDropDown.Layout.Column = 1;
            app.LayerDropDown.Value = 'Select Layer';

            % Create PerspectiveLabel
            app.PerspectiveLabel = uilabel(app.ReviewLayout);
            app.PerspectiveLabel.FontColor = [1 1 1];
            app.PerspectiveLabel.Layout.Row = 1;
            app.PerspectiveLabel.Layout.Column = 1;
            app.PerspectiveLabel.Text = 'Perspective';

            % Create PerspectiveDropDown
            app.PerspectiveDropDown = uidropdown(app.ReviewLayout);
            app.PerspectiveDropDown.Items = {'Full Head', 'Simulation Grid', ''};
            app.PerspectiveDropDown.ItemsData = {'head', 'sim'};
            app.PerspectiveDropDown.ValueChangedFcn = createCallbackFcn(app, @PerspectiveDropDownValueChanged, true);
            app.PerspectiveDropDown.FontSize = 14;
            app.PerspectiveDropDown.FontWeight = 'bold';
            app.PerspectiveDropDown.FontColor = [1 1 1];
            app.PerspectiveDropDown.BackgroundColor = [0.149 0.149 0.149];
            app.PerspectiveDropDown.Layout.Row = 2;
            app.PerspectiveDropDown.Layout.Column = 1;
            app.PerspectiveDropDown.Value = 'head';

            % Create ViewLabel
            app.ViewLabel = uilabel(app.ReviewLayout);
            app.ViewLabel.FontColor = [1 1 1];
            app.ViewLabel.Layout.Row = 3;
            app.ViewLabel.Layout.Column = 1;
            app.ViewLabel.Text = 'View';

            % Create ViewDropDown
            app.ViewDropDown = uidropdown(app.ReviewLayout);
            app.ViewDropDown.Items = {'Select View', ''};
            app.ViewDropDown.ValueChangedFcn = createCallbackFcn(app, @ViewDropDownValueChanged, true);
            app.ViewDropDown.FontSize = 14;
            app.ViewDropDown.FontWeight = 'bold';
            app.ViewDropDown.FontColor = [1 1 1];
            app.ViewDropDown.BackgroundColor = [0.149 0.149 0.149];
            app.ViewDropDown.Layout.Row = 4;
            app.ViewDropDown.Layout.Column = 1;
            app.ViewDropDown.Value = 'Select View';

            % Create SelectedVoxelTable
            app.SelectedVoxelTable = uitable(app.ReviewLayout);
            app.SelectedVoxelTable.BackgroundColor = [0.149 0.149 0.149;0.251 0.251 0.251];
            app.SelectedVoxelTable.ColumnName = '';
            app.SelectedVoxelTable.ColumnWidth = {90, 75, 60};
            app.SelectedVoxelTable.RowName = {};
            app.SelectedVoxelTable.ForegroundColor = [1 1 1];
            app.SelectedVoxelTable.Layout.Row = 8;
            app.SelectedVoxelTable.Layout.Column = 1;

            % Create GoToLabel
            app.GoToLabel = uilabel(app.ReviewLayout);
            app.GoToLabel.FontColor = [1 1 1];
            app.GoToLabel.Layout.Row = 9;
            app.GoToLabel.Layout.Column = 1;
            app.GoToLabel.Text = 'Go To';

            % Create GridLayout2
            app.GridLayout2 = uigridlayout(app.ReviewLayout);
            app.GridLayout2.RowHeight = {'1x'};
            app.GridLayout2.Padding = [0 0 0 0];
            app.GridLayout2.Layout.Row = 10;
            app.GridLayout2.Layout.Column = 1;
            app.GridLayout2.BackgroundColor = [0 0 0];

            % Create GoToTargetButton
            app.GoToTargetButton = uibutton(app.GridLayout2, 'push');
            app.GoToTargetButton.ButtonPushedFcn = createCallbackFcn(app, @GoToTargetButtonPushed, true);
            app.GoToTargetButton.BackgroundColor = [0.149 0.149 0.149];
            app.GoToTargetButton.FontWeight = 'bold';
            app.GoToTargetButton.FontColor = [1 1 1];
            app.GoToTargetButton.Layout.Row = 1;
            app.GoToTargetButton.Layout.Column = 1;
            app.GoToTargetButton.Text = 'Target';

            % Create GoToOriginButton
            app.GoToOriginButton = uibutton(app.GridLayout2, 'push');
            app.GoToOriginButton.ButtonPushedFcn = createCallbackFcn(app, @GoToOriginButtonPushed, true);
            app.GoToOriginButton.BackgroundColor = [0.149 0.149 0.149];
            app.GoToOriginButton.FontWeight = 'bold';
            app.GoToOriginButton.FontColor = [1 1 1];
            app.GoToOriginButton.Layout.Row = 1;
            app.GoToOriginButton.Layout.Column = 2;
            app.GoToOriginButton.Text = 'Origin';

            % Create PlanTab
            app.PlanTab = uitab(app.TabGroup);
            app.PlanTab.Title = 'Plan';

            % Create PlanTabLayout
            app.PlanTabLayout = uigridlayout(app.PlanTab);
            app.PlanTabLayout.ColumnWidth = {'1x'};
            app.PlanTabLayout.RowHeight = {'1x'};
            app.PlanTabLayout.Padding = [0 0 0 0];
            app.PlanTabLayout.BackgroundColor = [0 0 0];

            % Create PlanPanel
            app.PlanPanel = uipanel(app.PlanTabLayout);
            app.PlanPanel.Enable = 'off';
            app.PlanPanel.BorderType = 'none';
            app.PlanPanel.BackgroundColor = [0 0 0];
            app.PlanPanel.Layout.Row = 1;
            app.PlanPanel.Layout.Column = 1;

            % Create PlanLayout
            app.PlanLayout = uigridlayout(app.PlanPanel);
            app.PlanLayout.ColumnWidth = {'1x'};
            app.PlanLayout.RowHeight = {20, 30, 20, 30, 20, '1x', 50, 20, '1x', '1x'};
            app.PlanLayout.BackgroundColor = [0 0 0];

            % Create SelectPlanLabel
            app.SelectPlanLabel = uilabel(app.PlanLayout);
            app.SelectPlanLabel.FontColor = [1 1 1];
            app.SelectPlanLabel.Layout.Row = 3;
            app.SelectPlanLabel.Layout.Column = 1;
            app.SelectPlanLabel.Text = 'Plan';

            % Create PlanTreatmentButton
            app.PlanTreatmentButton = uibutton(app.PlanLayout, 'push');
            app.PlanTreatmentButton.ButtonPushedFcn = createCallbackFcn(app, @PlanTreatmentButtonPushed, true);
            app.PlanTreatmentButton.BackgroundColor = [0.149 0.149 0.149];
            app.PlanTreatmentButton.FontSize = 16;
            app.PlanTreatmentButton.FontWeight = 'bold';
            app.PlanTreatmentButton.FontColor = [1 1 1];
            app.PlanTreatmentButton.Layout.Row = 7;
            app.PlanTreatmentButton.Layout.Column = 1;
            app.PlanTreatmentButton.Text = 'Plan Treatment';

            % Create TreatmentPlanSettingsLabel
            app.TreatmentPlanSettingsLabel = uilabel(app.PlanLayout);
            app.TreatmentPlanSettingsLabel.FontColor = [1 1 1];
            app.TreatmentPlanSettingsLabel.Layout.Row = 5;
            app.TreatmentPlanSettingsLabel.Layout.Column = 1;
            app.TreatmentPlanSettingsLabel.Text = 'Treatment Plan Settings';

            % Create PlanTable
            app.PlanTable = uitable(app.PlanLayout);
            app.PlanTable.BackgroundColor = [0.149 0.149 0.149;0.251 0.251 0.251];
            app.PlanTable.ColumnName = '';
            app.PlanTable.RowName = {};
            app.PlanTable.ForegroundColor = [1 1 1];
            app.PlanTable.Layout.Row = 6;
            app.PlanTable.Layout.Column = 1;

            % Create SelectTargetLabel
            app.SelectTargetLabel = uilabel(app.PlanLayout);
            app.SelectTargetLabel.FontColor = [1 1 1];
            app.SelectTargetLabel.Layout.Row = 1;
            app.SelectTargetLabel.Layout.Column = 1;
            app.SelectTargetLabel.Text = 'Target';

            % Create SolutionLabel
            app.SolutionLabel = uilabel(app.PlanLayout);
            app.SolutionLabel.FontColor = [1 1 1];
            app.SolutionLabel.Layout.Row = 8;
            app.SolutionLabel.Layout.Column = 1;
            app.SolutionLabel.Text = 'Treatment Solution Results:';

            % Create SolutionTable
            app.SolutionTable = uitable(app.PlanLayout);
            app.SolutionTable.BackgroundColor = [0.149 0.149 0.149;0.251 0.251 0.251];
            app.SolutionTable.ColumnName = '';
            app.SolutionTable.RowName = {};
            app.SolutionTable.ForegroundColor = [1 1 1];
            app.SolutionTable.Layout.Row = 9;
            app.SolutionTable.Layout.Column = 1;

            % Create GridLayout3
            app.GridLayout3 = uigridlayout(app.PlanLayout);
            app.GridLayout3.ColumnWidth = {'1x', 20};
            app.GridLayout3.RowHeight = {'1x'};
            app.GridLayout3.Padding = [0 0 0 0];
            app.GridLayout3.Layout.Row = 4;
            app.GridLayout3.Layout.Column = 1;
            app.GridLayout3.BackgroundColor = [0 0 0];

            % Create TargetOKLamp
            app.TargetOKLamp = uilamp(app.GridLayout3);
            app.TargetOKLamp.Layout.Row = 1;
            app.TargetOKLamp.Layout.Column = 2;

            % Create PlanDropDown
            app.PlanDropDown = uidropdown(app.GridLayout3);
            app.PlanDropDown.Items = {'Select Plan'};
            app.PlanDropDown.ValueChangedFcn = createCallbackFcn(app, @PlanDropDownValueChanged, true);
            app.PlanDropDown.FontSize = 14;
            app.PlanDropDown.FontWeight = 'bold';
            app.PlanDropDown.FontColor = [1 1 1];
            app.PlanDropDown.BackgroundColor = [0.149 0.149 0.149];
            app.PlanDropDown.Layout.Row = 1;
            app.PlanDropDown.Layout.Column = 1;
            app.PlanDropDown.Value = 'Select Plan';

            % Create TargetDropDown
            app.TargetDropDown = uidropdown(app.PlanLayout);
            app.TargetDropDown.Items = {'Select Target'};
            app.TargetDropDown.ValueChangedFcn = createCallbackFcn(app, @TargetDropDownValueChanged, true);
            app.TargetDropDown.FontSize = 14;
            app.TargetDropDown.FontWeight = 'bold';
            app.TargetDropDown.FontColor = [1 1 1];
            app.TargetDropDown.BackgroundColor = [0.149 0.149 0.149];
            app.TargetDropDown.Layout.Row = 2;
            app.TargetDropDown.Layout.Column = 1;
            app.TargetDropDown.Value = 'Select Target';

            % Create TreatTab
            app.TreatTab = uitab(app.TabGroup);
            app.TreatTab.Title = 'Treat';

            % Create TreatTabLayout
            app.TreatTabLayout = uigridlayout(app.TreatTab);
            app.TreatTabLayout.ColumnWidth = {'1x'};
            app.TreatTabLayout.RowHeight = {'1x'};
            app.TreatTabLayout.Padding = [0 0 0 0];
            app.TreatTabLayout.BackgroundColor = [0 0 0];

            % Create TreatPanel
            app.TreatPanel = uipanel(app.TreatTabLayout);
            app.TreatPanel.BorderType = 'none';
            app.TreatPanel.BackgroundColor = [0 0 0];
            app.TreatPanel.Layout.Row = 1;
            app.TreatPanel.Layout.Column = 1;

            % Create TreatLayout
            app.TreatLayout = uigridlayout(app.TreatPanel);
            app.TreatLayout.ColumnWidth = {'1x'};
            app.TreatLayout.RowHeight = {20, 30, '1x', '1x', 50};
            app.TreatLayout.BackgroundColor = [0 0 0];

            % Create StartTreatmentButton
            app.StartTreatmentButton = uibutton(app.TreatLayout, 'push');
            app.StartTreatmentButton.ButtonPushedFcn = createCallbackFcn(app, @StartTreatmentButtonPushed, true);
            app.StartTreatmentButton.BackgroundColor = [0.149 0.149 0.149];
            app.StartTreatmentButton.FontSize = 16;
            app.StartTreatmentButton.FontWeight = 'bold';
            app.StartTreatmentButton.FontColor = [1 1 1];
            app.StartTreatmentButton.Layout.Row = 5;
            app.StartTreatmentButton.Layout.Column = 1;
            app.StartTreatmentButton.Text = 'Start Treatment';

            % Create TreatmentSystemLabel
            app.TreatmentSystemLabel = uilabel(app.TreatLayout);
            app.TreatmentSystemLabel.FontColor = [1 1 1];
            app.TreatmentSystemLabel.Layout.Row = 1;
            app.TreatmentSystemLabel.Layout.Column = 1;
            app.TreatmentSystemLabel.Text = 'Treatment System';

            % Create SystemDropDown
            app.SystemDropDown = uidropdown(app.TreatLayout);
            app.SystemDropDown.Items = {'Select Treatment System'};
            app.SystemDropDown.ValueChangedFcn = createCallbackFcn(app, @SystemDropDownValueChanged, true);
            app.SystemDropDown.FontSize = 14;
            app.SystemDropDown.FontWeight = 'bold';
            app.SystemDropDown.FontColor = [1 1 1];
            app.SystemDropDown.BackgroundColor = [0.149 0.149 0.149];
            app.SystemDropDown.Layout.Row = 2;
            app.SystemDropDown.Layout.Column = 1;
            app.SystemDropDown.Value = 'Select Treatment System';

            % Create SystemTable
            app.SystemTable = uitable(app.TreatLayout);
            app.SystemTable.BackgroundColor = [0.149 0.149 0.149;0.251 0.251 0.251];
            app.SystemTable.ColumnName = '';
            app.SystemTable.RowName = {};
            app.SystemTable.ForegroundColor = [1 1 1];
            app.SystemTable.Layout.Row = 3;
            app.SystemTable.Layout.Column = 1;

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = FUSPlan_exported(varargin)

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @(app)Startup(app, varargin{:}))

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end