classdef TransWidget < matlab.apps.AppBase
% TRANSWIDGET Create Transducer Placement Widget
%
% Optional Parameters
%   'parent': ui parent
%   'trans': fus.xdc. Transducer
%   'trans_handle': transducer handle
%   'skin_sph': skin surface in spherical coords
%   'callback': function_handle
%   'standoff': fus.xdc.Standoff
%   'fontsize': font Size. Default 20.
%   'tabs' (1xN string) ['jog', 'rotate','orbit','translate']
%   'log' fus.util.Logger
    properties (Access = public)
        UIFigure                      matlab.ui.Figure
        FigureLayout                  matlab.ui.container.GridLayout
        TabGroup                      matlab.ui.container.TabGroup
        TransducerJogTab              matlab.ui.container.Tab
        JogLayout                     matlab.ui.container.GridLayout
        JogIncrementmmEditFieldLabel  matlab.ui.control.Label
        JogIncrement                  matlab.ui.control.NumericEditField
        JogUpButton                   matlab.ui.control.Button
        JogDownButton                 matlab.ui.control.Button
        JogForwardButton              matlab.ui.control.Button
        JogBackButton                 matlab.ui.control.Button
        JogBackForwardImage           matlab.ui.control.Image
        JogUpDownImage                matlab.ui.control.Image
        JogRightButton                matlab.ui.control.Button
        JogLeftButton                 matlab.ui.control.Button
        JogLeftRightImage             matlab.ui.control.Image
        TransducerRotateTab           matlab.ui.container.Tab
        RotateLayout                  matlab.ui.container.GridLayout
        RotateIncrementdegLabel       matlab.ui.control.Label
        RotateIncrement               matlab.ui.control.NumericEditField
        RollRightButton               matlab.ui.control.Button
        RollLeftButton                matlab.ui.control.Button
        YawLeftButton                 matlab.ui.control.Button
        YawRightButton                matlab.ui.control.Button
        PitchDownButton               matlab.ui.control.Button
        PitchUpButton                 matlab.ui.control.Button
        RollImage                     matlab.ui.control.Image
        YawImage                      matlab.ui.control.Image
        PitchImage                    matlab.ui.control.Image
        HeadOrbitTab                  matlab.ui.container.Tab
        OrbitLayout                   matlab.ui.container.GridLayout
        OrbitIncrementdegEditFieldLabel  matlab.ui.control.Label
        OrbitIncrement                matlab.ui.control.NumericEditField
        SnaptoSurfaceButton           matlab.ui.control.Button
        SnapImage                     matlab.ui.control.Image
        OrbitUpButton                 matlab.ui.control.Button
        OrbitDownButton               matlab.ui.control.Button
        OrbitRightButton              matlab.ui.control.Button
        OrbitLeftButton               matlab.ui.control.Button
        OrbitUpDown                   matlab.ui.control.Image
        OrbitLeftRightImage           matlab.ui.control.Image
        GlobalTranslateTab            matlab.ui.container.Tab
        TranslateLayout               matlab.ui.container.GridLayout
        TranslateIncrement            matlab.ui.control.NumericEditField
        TranslateIncrementmmLabel_2   matlab.ui.control.Label
        PatientSuperiorButton         matlab.ui.control.Button
        PatientInferiorButton         matlab.ui.control.Button
        PatientPosteriorButton        matlab.ui.control.Button
        PatientAnteriorButton         matlab.ui.control.Button
        PatientLeftButton             matlab.ui.control.Button
        PatientRightButton            matlab.ui.control.Button
        PatientSImage                 matlab.ui.control.Image
        PatientPImage                 matlab.ui.control.Image
        PatientLImage                 matlab.ui.control.Image
        deletefcn                     function_handle = function_handle.empty
        UserData                      struct = struct()
    end

    
    properties (Access = public)
        trans
        standoff
        skin_sph
        trans_handle
        callback = function_handle.empty
        log fus.util.Logger = fus.util.Logger.get()
    end
    
    methods (Static, Access = public)
        function app = from_scene(scene, options)
            arguments
                scene fus.Scene
                options.trans fus.xdc.Transducer
                options.standoff fus.xdc.Standoff = fus.xdc.Standoff()
                options.skin_thresh (1,1) double = 0.25;
                options.fourup_parent = []
                options.parent = []
                options.fontsize = 20;
                options.tabs (1,:) string {mustBeMember(options.tabs, ["jog", "rotate", "orbit", "translate"])} = ["jog", "rotate", "orbit", "translate"]
                options.log fus.util.Logger = fus.util.Logger.get();
            
            end
            vol = scene.volumes(1);
            cmap = scene.colormaps(1);
            if isfield(options, 'trans')
                trans = options.trans;
            else
                trans = scene.transducer;
            end
            [skin_lps, skin_sph] = fus.seg.detect_skin(vol, "skin_thresh", options.skin_thresh);
            f = fus.ui.FourUp(vol, cmap, ...
                "parent", options.fourup_parent, ...
                "axes_arrangement", [[1 1;2 2;3 3],4*ones(3,4),zeros(3,1)],...
                "axes_props", struct("Color","k"));
            grid = f.axes(4).Parent;
            cax = uiaxes(grid);
            cax.Layout.Column = 7;
            cax.Layout.Row = [1 3];
            cmap_ui = fus.ui.ColorMapper_UI(cmap, "axes",cax, "on_update", @f.update_images, "range", vol.percentile([0, 1]));
            skin_handle = surf(f.axes(4), skin_lps{:}, "EdgeColor","none", "FaceLighting","Gouraud", "FaceColor", "y", "FaceAlpha", 0.2);
            trans_handle = trans.draw("ax", f.axes(4), "transform", true);
            app = fus.xdc.TransWidget(...
                "parent", options.parent, ...
                "fontsize", options.fontsize, ...
                "log", options.log, ...
                "tabs", options.tabs, ...
                "trans", trans, ...
                "trans_handle", trans_handle, ...
                "skin_sph", skin_sph, ...
                "standoff", options.standoff);
        end
        
        function app = from_db(db, subject_id, session_id, options)
            arguments
                db fus.Database
                subject_id (1,1) string
                session_id (1,1) string
                options.trans fus.xdc.Transducer
                options.standoff fus.xdc.Standoff = fus.xdc.Standoff();
                options.skin_thresh (1,1) double = 0.25;
                options.fourup_parent = []
                options.parent = []
                options.fontsize = 20;
                options.tabs (1,:) string {mustBeMember(options.tabs, ["jog", "rotate", "orbit", "translate"])} = ["jog", "rotate", "orbit", "translate"]
                options.log fus.util.Logger = fus.util.Logger.get();
            end
            subject = db.load_subject(subject_id);
            session = db.load_session(subject, session_id);
            scene = session.to_scene();
            base = scene.transform_base();
            args = fus.util.struct2args(options);
            app = fus.xdc.TransWidget.from_scene(base, args{:});
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)
        % Button pushed function: JogBackButton, JogDownButton, 
        % JogForwardButton, JogLeftButton, JogRightButton, 
        % JogUpButton, OrbitDownButton, OrbitLeftButton, 
        % OrbitRightButton, OrbitUpButton, PatientAnteriorButton, 
        % PatientInferiorButton, PatientLeftButton, 
        % PatientPosteriorButton, PatientRightButton, 
        % PatientSuperiorButton, PitchDownButton, PitchUpButton, 
        % RollLeftButton, RollRightButton, SnaptoSurfaceButton, 
        % YawLeftButton, YawRightButton
        function JogPushed(app, event)
            pol = (-1)^(string(event.Source.Tag(1))=="-");
            tag = string(event.Source.Tag(2:end));
            app.log.debug("Jogging %s (%+d)", tag, pol)
            app.log.debug('from:\n%s', formattedDisplayText(app.trans.matrix))
            switch tag
                case {"pitch", "yaw", "roll"}
                    th = app.RotateIncrement.Value*pol;
                    switch tag
                        case "pitch"
                            mr = [1 0 0; 0 cosd(th) -sind(th); 0 sind(th), cosd(th)];
                        case "yaw"
                            mr = [cosd(th) 0 sind(th); 0, 1, 0; -sind(th), 0, cosd(th)];
                        case "roll"
                            mr = [cosd(th), -sind(th), 0; sind(th) cosd(th), 0; 0 0 1];
                    end
                    m = [mr, zeros(3,1); zeros(1,3) 1];
                    app.trans.matrix = app.trans.matrix * m;
                case {"x", "y", "z"}
                    x = app.JogIncrement.Value*pol;
                    switch tag
                        case "x"
                            mt  = [x;0;0];
                        case "y"
                            mt = [0;x;0];
                        case "z"
                            mt = [0;0;x];
                    end
                    m = [eye(3) mt; zeros(1,3) 1];
                    app.trans.matrix = app.trans.matrix * m;
                case {"theta", "phi"}
                    m = app.trans.matrix/app.standoff.offset_matrix;
                    [th, phi, ~] = fus.seg.lps2sph(m(1,4), m(2,4), m(3,4));
                    dth = app.OrbitIncrement.Value*pol;
                    switch tag
                        case "theta"
                            th = th + dth;
                        case "phi"
                            phi = phi + dth;
                    end
                    app.trans.matrix = fus.seg.fit_to_skin(th, phi, app.skin_sph, "offset_matrix", app.standoff.offset_matrix);
                case "snap"
                     m = app.trans.matrix/app.standoff.offset_matrix;
                    [th, phi, ~] = fus.seg.lps2sph(m(1,4), m(2,4), m(3,4));
                    app.trans.matrix = fus.seg.fit_to_skin(th, phi, app.skin_sph, "offset_matrix", app.standoff.offset_matrix);
                case {"L", "P", "S"}
                    x = app.TranslateIncrement.Value*pol;
                    switch tag
                        case "L"
                            mt  = [x;0;0];
                        case "P"
                            mt = [0;x;0];
                        case "S"
                            mt = [0;0;x];
                    end
                    m = [eye(3) mt; zeros(1,3) 1];
                    app.trans.matrix = m*app.trans.matrix;
                otherwise
                    app.log.throw_error('Unrecognized tag "%s"', tag)
            end
            app.log.debug('to:\n%s', formattedDisplayText(app.trans.matrix))
            corners = app.trans.get_corners("transform", true);
            set(app.trans_handle, "XData", corners{1}, "YData", corners{2}, "ZData", corners{3});
            if ~isempty(app.callback)
                if iscell(app.callback)
                    app.callback{1}(app.callback{2:end});
                else
                    app.callback();
                end
            end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app, parent, options)
            arguments
                app fus.xdc.TransWidget
                parent
                options.fontsize (1,1) double {mustBeInteger} = 20
                options.tabs (1,:) string {mustBeMember(options.tabs, ["jog", "rotate", "orbit", "translate"])} = ["jog", "rotate", "orbit", "translate"]
            end
            % Create TabGroup
            app.TabGroup = uitabgroup(parent);
            icon_dir = fullfile(fileparts(mfilename('fullpath')),'icons');
            addpath(icon_dir);
            if ismember("jog", options.tabs)
                % Create TransducerJogTab
                app.TransducerJogTab = uitab(app.TabGroup);
                app.TransducerJogTab.Title = 'Transducer Jog';

                % Create JogLayout
                app.JogLayout = uigridlayout(app.TransducerJogTab);
                app.JogLayout.ColumnWidth = {'1x', '1x', '1x'};
                app.JogLayout.RowHeight = {'1x', '1x', '1x', 2*options.fontsize};

                % Create JogLeftRightImage
                app.JogLeftRightImage = uiimage(app.JogLayout);
                app.JogLeftRightImage.Layout.Row = 1;
                app.JogLeftRightImage.Layout.Column = 1;
                app.JogLeftRightImage.ImageSource = 'jog_leftright.png';

                % Create JogLeftButton
                app.JogLeftButton = uibutton(app.JogLayout, 'push');
                app.JogLeftButton.ButtonPushedFcn = createCallbackFcn(app, @JogPushed, true);
                app.JogLeftButton.Tag = '+x';
                app.JogLeftButton.WordWrap = 'on';
                app.JogLeftButton.FontSize = options.fontsize;
                app.JogLeftButton.FontWeight = 'bold';
                app.JogLeftButton.Layout.Row = 1;
                app.JogLeftButton.Layout.Column = 2;
                app.JogLeftButton.Text = {'Jog'; 'Left'};

                % Create JogRightButton
                app.JogRightButton = uibutton(app.JogLayout, 'push');
                app.JogRightButton.ButtonPushedFcn = createCallbackFcn(app, @JogPushed, true);
                app.JogRightButton.Tag = '-x';
                app.JogRightButton.WordWrap = 'on';
                app.JogRightButton.FontSize = options.fontsize;
                app.JogRightButton.FontWeight = 'bold';
                app.JogRightButton.Layout.Row = 1;
                app.JogRightButton.Layout.Column = 3;
                app.JogRightButton.Text = {'Jog'; 'Right'; ''};

                % Create JogUpDownImage
                app.JogUpDownImage = uiimage(app.JogLayout);
                app.JogUpDownImage.Layout.Row = 2;
                app.JogUpDownImage.Layout.Column = 1;
                app.JogUpDownImage.ImageSource = 'jog_updown.png';

                % Create JogBackForwardImage
                app.JogBackForwardImage = uiimage(app.JogLayout);
                app.JogBackForwardImage.Layout.Row = 3;
                app.JogBackForwardImage.Layout.Column = 1;
                app.JogBackForwardImage.ImageSource = 'jog_backforward.png';

                % Create JogBackButton
                app.JogBackButton = uibutton(app.JogLayout, 'push');
                app.JogBackButton.ButtonPushedFcn = createCallbackFcn(app, @JogPushed, true);
                app.JogBackButton.Tag = '-z';
                app.JogBackButton.WordWrap = 'on';
                app.JogBackButton.FontSize = options.fontsize;
                app.JogBackButton.FontWeight = 'bold';
                app.JogBackButton.Layout.Row = 3;
                app.JogBackButton.Layout.Column = 2;
                app.JogBackButton.Text = {'Jog'; 'Back'};

                % Create JogForwardButton
                app.JogForwardButton = uibutton(app.JogLayout, 'push');
                app.JogForwardButton.ButtonPushedFcn = createCallbackFcn(app, @JogPushed, true);
                app.JogForwardButton.Tag = '+z';
                app.JogForwardButton.WordWrap = 'on';
                app.JogForwardButton.FontSize = options.fontsize;
                app.JogForwardButton.FontWeight = 'bold';
                app.JogForwardButton.Layout.Row = 3;
                app.JogForwardButton.Layout.Column = 3;
                app.JogForwardButton.Text = {'Jog'; 'Forward'};

                % Create JogDownButton
                app.JogDownButton = uibutton(app.JogLayout, 'push');
                app.JogDownButton.ButtonPushedFcn = createCallbackFcn(app, @JogPushed, true);
                app.JogDownButton.Tag = '-y';
                app.JogDownButton.WordWrap = 'on';
                app.JogDownButton.FontSize = options.fontsize;
                app.JogDownButton.FontWeight = 'bold';
                app.JogDownButton.Layout.Row = 2;
                app.JogDownButton.Layout.Column = 2;
                app.JogDownButton.Text = {'Jog'; 'Down'};

                % Create JogUpButton
                app.JogUpButton = uibutton(app.JogLayout, 'push');
                app.JogUpButton.ButtonPushedFcn = createCallbackFcn(app, @JogPushed, true);
                app.JogUpButton.Tag = '+y';
                app.JogUpButton.WordWrap = 'on';
                app.JogUpButton.FontSize = options.fontsize;
                app.JogUpButton.FontWeight = 'bold';
                app.JogUpButton.Layout.Row = 2;
                app.JogUpButton.Layout.Column = 3;
                app.JogUpButton.Text = {'Jog'; 'Up'};

                % Create JogIncrement
                app.JogIncrement = uieditfield(app.JogLayout, 'numeric');
                app.JogIncrement.Limits = [0.001 Inf];
                app.JogIncrement.FontSize = options.fontsize;
                app.JogIncrement.FontWeight = 'bold';
                app.JogIncrement.Layout.Row = 4;
                app.JogIncrement.Layout.Column = 3;
                app.JogIncrement.Value = 3;

                % Create JogIncrementmmEditFieldLabel
                app.JogIncrementmmEditFieldLabel = uilabel(app.JogLayout);
                app.JogIncrementmmEditFieldLabel.HorizontalAlignment = 'right';
                app.JogIncrementmmEditFieldLabel.FontSize = options.fontsize;
                app.JogIncrementmmEditFieldLabel.Layout.Row = 4;
                app.JogIncrementmmEditFieldLabel.Layout.Column = [1 2];
                app.JogIncrementmmEditFieldLabel.Text = 'Jog Increment (mm)';
            end
            
            if ismember("rotate", options.tabs)
                % Create TransducerRotateTab
                app.TransducerRotateTab = uitab(app.TabGroup);
                app.TransducerRotateTab.Title = 'Transducer Rotate';

                % Create RotateLayout
                app.RotateLayout = uigridlayout(app.TransducerRotateTab);
                app.RotateLayout.ColumnWidth = {'1x', '1x', '1x'};
                app.RotateLayout.RowHeight = {'1x', '1x', '1x', 2*options.fontsize};

                % Create PitchImage
                app.PitchImage = uiimage(app.RotateLayout);
                app.PitchImage.Layout.Row = 1;
                app.PitchImage.Layout.Column = 1;
                app.PitchImage.ImageSource = 'rotate_pitch.png';

                % Create YawImage
                app.YawImage = uiimage(app.RotateLayout);
                app.YawImage.Layout.Row = 2;
                app.YawImage.Layout.Column = 1;
                app.YawImage.ImageSource = 'rotate_yaw.png';

                % Create RollImage
                app.RollImage = uiimage(app.RotateLayout);
                app.RollImage.Layout.Row = 3;
                app.RollImage.Layout.Column = 1;
                app.RollImage.ImageSource = 'rotate_roll.png';

                % Create PitchUpButton
                app.PitchUpButton = uibutton(app.RotateLayout, 'push');
                app.PitchUpButton.ButtonPushedFcn = createCallbackFcn(app, @JogPushed, true);
                app.PitchUpButton.Tag = '-pitch';
                app.PitchUpButton.WordWrap = 'on';
                app.PitchUpButton.FontSize = options.fontsize;
                app.PitchUpButton.FontWeight = 'bold';
                app.PitchUpButton.Layout.Row = 1;
                app.PitchUpButton.Layout.Column = 2;
                app.PitchUpButton.Text = {'Pitch'; 'Up'};

                % Create PitchDownButton
                app.PitchDownButton = uibutton(app.RotateLayout, 'push');
                app.PitchDownButton.ButtonPushedFcn = createCallbackFcn(app, @JogPushed, true);
                app.PitchDownButton.Tag = '+pitch';
                app.PitchDownButton.WordWrap = 'on';
                app.PitchDownButton.FontSize = options.fontsize;
                app.PitchDownButton.FontWeight = 'bold';
                app.PitchDownButton.Layout.Row = 1;
                app.PitchDownButton.Layout.Column = 3;
                app.PitchDownButton.Text = {'Pitch'; 'Down'};

                % Create YawRightButton
                app.YawRightButton = uibutton(app.RotateLayout, 'push');
                app.YawRightButton.ButtonPushedFcn = createCallbackFcn(app, @JogPushed, true);
                app.YawRightButton.Tag = '-yaw';
                app.YawRightButton.WordWrap = 'on';
                app.YawRightButton.FontSize = options.fontsize;
                app.YawRightButton.FontWeight = 'bold';
                app.YawRightButton.Layout.Row = 2;
                app.YawRightButton.Layout.Column = 2;
                app.YawRightButton.Text = {'Yaw'; 'Right'};

                % Create YawLeftButton
                app.YawLeftButton = uibutton(app.RotateLayout, 'push');
                app.YawLeftButton.ButtonPushedFcn = createCallbackFcn(app, @JogPushed, true);
                app.YawLeftButton.Tag = '+yaw';
                app.YawLeftButton.WordWrap = 'on';
                app.YawLeftButton.FontSize = options.fontsize;
                app.YawLeftButton.FontWeight = 'bold';
                app.YawLeftButton.Layout.Row = 2;
                app.YawLeftButton.Layout.Column = 3;
                app.YawLeftButton.Text = {'Yaw'; 'Left'};

                % Create RollLeftButton
                app.RollLeftButton = uibutton(app.RotateLayout, 'push');
                app.RollLeftButton.ButtonPushedFcn = createCallbackFcn(app, @JogPushed, true);
                app.RollLeftButton.Tag = '-roll';
                app.RollLeftButton.WordWrap = 'on';
                app.RollLeftButton.FontSize = options.fontsize;
                app.RollLeftButton.FontWeight = 'bold';
                app.RollLeftButton.Layout.Row = 3;
                app.RollLeftButton.Layout.Column = 2;
                app.RollLeftButton.Text = {'Roll'; 'Left'};

                % Create RollRightButton
                app.RollRightButton = uibutton(app.RotateLayout, 'push');
                app.RollRightButton.ButtonPushedFcn = createCallbackFcn(app, @JogPushed, true);
                app.RollRightButton.Tag = '+roll';
                app.RollRightButton.WordWrap = 'on';
                app.RollRightButton.FontSize = options.fontsize;
                app.RollRightButton.FontWeight = 'bold';
                app.RollRightButton.Layout.Row = 3;
                app.RollRightButton.Layout.Column = 3;
                app.RollRightButton.Text = {'Roll'; 'Right'};

                % Create RotateIncrement
                app.RotateIncrement = uieditfield(app.RotateLayout, 'numeric');
                app.RotateIncrement.Limits = [0.001 Inf];
                app.RotateIncrement.FontSize = options.fontsize;
                app.RotateIncrement.FontWeight = 'bold';
                app.RotateIncrement.Layout.Row = 4;
                app.RotateIncrement.Layout.Column = 3;
                app.RotateIncrement.Value = 3;

                % Create RotateIncrementdegLabel
                app.RotateIncrementdegLabel = uilabel(app.RotateLayout);
                app.RotateIncrementdegLabel.HorizontalAlignment = 'right';
                app.RotateIncrementdegLabel.FontSize = options.fontsize;
                app.RotateIncrementdegLabel.Layout.Row = 4;
                app.RotateIncrementdegLabel.Layout.Column = [1 2];
                app.RotateIncrementdegLabel.Text = 'Rotate Increment (deg)';
            end
            
            if ismember("orbit", options.tabs)
                % Create HeadOrbitTab
                app.HeadOrbitTab = uitab(app.TabGroup);
                app.HeadOrbitTab.Title = 'Head Orbit';

                % Create OrbitLayout
                app.OrbitLayout = uigridlayout(app.HeadOrbitTab);
                app.OrbitLayout.ColumnWidth = {'1x', '1x', '1x'};
                app.OrbitLayout.RowHeight = {'1x', '1x', '1x', 2*options.fontsize};

                % Create OrbitLeftRightImage
                app.OrbitLeftRightImage = uiimage(app.OrbitLayout);
                app.OrbitLeftRightImage.Layout.Row = 2;
                app.OrbitLeftRightImage.Layout.Column = 1;
                app.OrbitLeftRightImage.ImageSource = 'orbit_leftright.png';

                % Create OrbitUpDown
                app.OrbitUpDown = uiimage(app.OrbitLayout);
                app.OrbitUpDown.Layout.Row = 3;
                app.OrbitUpDown.Layout.Column = 1;
                app.OrbitUpDown.ImageSource = 'orbit_updown.png';

                % Create OrbitLeftButton
                app.OrbitLeftButton = uibutton(app.OrbitLayout, 'push');
                app.OrbitLeftButton.ButtonPushedFcn = createCallbackFcn(app, @JogPushed, true);
                app.OrbitLeftButton.Tag = '-theta';
                app.OrbitLeftButton.WordWrap = 'on';
                app.OrbitLeftButton.FontSize = options.fontsize;
                app.OrbitLeftButton.FontWeight = 'bold';
                app.OrbitLeftButton.Layout.Row = 2;
                app.OrbitLeftButton.Layout.Column = 2;
                app.OrbitLeftButton.Text = {'Orbit'; 'Left'};

                % Create OrbitRightButton
                app.OrbitRightButton = uibutton(app.OrbitLayout, 'push');
                app.OrbitRightButton.ButtonPushedFcn = createCallbackFcn(app, @JogPushed, true);
                app.OrbitRightButton.Tag = '+theta';
                app.OrbitRightButton.WordWrap = 'on';
                app.OrbitRightButton.FontSize = options.fontsize;
                app.OrbitRightButton.FontWeight = 'bold';
                app.OrbitRightButton.Layout.Row = 2;
                app.OrbitRightButton.Layout.Column = 3;
                app.OrbitRightButton.Text = {'Orbit'; 'Right'};

                % Create OrbitDownButton
                app.OrbitDownButton = uibutton(app.OrbitLayout, 'push');
                app.OrbitDownButton.ButtonPushedFcn = createCallbackFcn(app, @JogPushed, true);
                app.OrbitDownButton.Tag = '-phi';
                app.OrbitDownButton.WordWrap = 'on';
                app.OrbitDownButton.FontSize = options.fontsize;
                app.OrbitDownButton.FontWeight = 'bold';
                app.OrbitDownButton.Layout.Row = 3;
                app.OrbitDownButton.Layout.Column = 2;
                app.OrbitDownButton.Text = {'Orbit'; 'Down'};

                % Create OrbitUpButton
                app.OrbitUpButton = uibutton(app.OrbitLayout, 'push');
                app.OrbitUpButton.ButtonPushedFcn = createCallbackFcn(app, @JogPushed, true);
                app.OrbitUpButton.Tag = '+phi';
                app.OrbitUpButton.WordWrap = 'on';
                app.OrbitUpButton.FontSize = options.fontsize;
                app.OrbitUpButton.FontWeight = 'bold';
                app.OrbitUpButton.Layout.Row = 3;
                app.OrbitUpButton.Layout.Column = 3;
                app.OrbitUpButton.Text = {'Orbit'; 'Up'};

                % Create SnapImage
                app.SnapImage = uiimage(app.OrbitLayout);
                app.SnapImage.Layout.Row = 1;
                app.SnapImage.Layout.Column = 1;
                app.SnapImage.ImageSource = 'orbit_snap.png';

                % Create SnaptoSurfaceButton
                app.SnaptoSurfaceButton = uibutton(app.OrbitLayout, 'push');
                app.SnaptoSurfaceButton.ButtonPushedFcn = createCallbackFcn(app, @JogPushed, true);
                app.SnaptoSurfaceButton.Tag = '+snap';
                app.SnaptoSurfaceButton.WordWrap = 'on';
                app.SnaptoSurfaceButton.FontSize = options.fontsize;
                app.SnaptoSurfaceButton.FontWeight = 'bold';
                app.SnaptoSurfaceButton.Layout.Row = 1;
                app.SnaptoSurfaceButton.Layout.Column = [2 3];
                app.SnaptoSurfaceButton.Text = {'Snap to'; 'Surface'};

                % Create OrbitIncrement
                app.OrbitIncrement = uieditfield(app.OrbitLayout, 'numeric');
                app.OrbitIncrement.Limits = [0.001 Inf];
                app.OrbitIncrement.FontSize = options.fontsize;
                app.OrbitIncrement.FontWeight = 'bold';
                app.OrbitIncrement.Layout.Row = 4;
                app.OrbitIncrement.Layout.Column = 3;
                app.OrbitIncrement.Value = 3;

                % Create OrbitIncrementdegEditFieldLabel
                app.OrbitIncrementdegEditFieldLabel = uilabel(app.OrbitLayout);
                app.OrbitIncrementdegEditFieldLabel.HorizontalAlignment = 'right';
                app.OrbitIncrementdegEditFieldLabel.FontSize = options.fontsize;
                app.OrbitIncrementdegEditFieldLabel.Layout.Row = 4;
                app.OrbitIncrementdegEditFieldLabel.Layout.Column = [1 2];
                app.OrbitIncrementdegEditFieldLabel.Text = 'Orbit Increment (deg)';
            end
            
            if ismember("translate", options.tabs)
                % Create GlobalTranslateTab
                app.GlobalTranslateTab = uitab(app.TabGroup);
                app.GlobalTranslateTab.Title = 'Global Translate';

                % Create TranslateLayout
                app.TranslateLayout = uigridlayout(app.GlobalTranslateTab);
                app.TranslateLayout.ColumnWidth = {'1x', '1x', '1x'};
                app.TranslateLayout.RowHeight = {'1x', '1x', '1x', 2*options.fontsize};

                % Create PatientLImage
                app.PatientLImage = uiimage(app.TranslateLayout);
                app.PatientLImage.Layout.Row = 1;
                app.PatientLImage.Layout.Column = 1;
                app.PatientLImage.ImageSource = 'translate_left.png';

                % Create PatientPImage
                app.PatientPImage = uiimage(app.TranslateLayout);
                app.PatientPImage.Layout.Row = 2;
                app.PatientPImage.Layout.Column = 1;
                app.PatientPImage.ImageSource = 'translate_posterior.png';

                % Create PatientSImage
                app.PatientSImage = uiimage(app.TranslateLayout);
                app.PatientSImage.Layout.Row = 3;
                app.PatientSImage.Layout.Column = 1;
                app.PatientSImage.ImageSource = 'translate_superior.png';

                % Create PatientRightButton
                app.PatientRightButton = uibutton(app.TranslateLayout, 'push');
                app.PatientRightButton.ButtonPushedFcn = createCallbackFcn(app, @JogPushed, true);
                app.PatientRightButton.Tag = '-L';
                app.PatientRightButton.WordWrap = 'on';
                app.PatientRightButton.FontSize = options.fontsize;
                app.PatientRightButton.FontWeight = 'bold';
                app.PatientRightButton.Layout.Row = 1;
                app.PatientRightButton.Layout.Column = 2;
                app.PatientRightButton.Text = {'Patient'; 'Right'};

                % Create PatientLeftButton
                app.PatientLeftButton = uibutton(app.TranslateLayout, 'push');
                app.PatientLeftButton.ButtonPushedFcn = createCallbackFcn(app, @JogPushed, true);
                app.PatientLeftButton.Tag = '+L';
                app.PatientLeftButton.WordWrap = 'on';
                app.PatientLeftButton.FontSize = options.fontsize;
                app.PatientLeftButton.FontWeight = 'bold';
                app.PatientLeftButton.Layout.Row = 1;
                app.PatientLeftButton.Layout.Column = 3;
                app.PatientLeftButton.Text = {'Patient'; 'Left'};

                % Create PatientAnteriorButton
                app.PatientAnteriorButton = uibutton(app.TranslateLayout, 'push');
                app.PatientAnteriorButton.ButtonPushedFcn = createCallbackFcn(app, @JogPushed, true);
                app.PatientAnteriorButton.Tag = '-P';
                app.PatientAnteriorButton.WordWrap = 'on';
                app.PatientAnteriorButton.FontSize = options.fontsize;
                app.PatientAnteriorButton.FontWeight = 'bold';
                app.PatientAnteriorButton.Layout.Row = 2;
                app.PatientAnteriorButton.Layout.Column = 2;
                app.PatientAnteriorButton.Text = {'Patient'; 'Anterior'};

                % Create PatientPosteriorButton
                app.PatientPosteriorButton = uibutton(app.TranslateLayout, 'push');
                app.PatientPosteriorButton.ButtonPushedFcn = createCallbackFcn(app, @JogPushed, true);
                app.PatientPosteriorButton.Tag = '+P';
                app.PatientPosteriorButton.WordWrap = 'on';
                app.PatientPosteriorButton.FontSize = options.fontsize;
                app.PatientPosteriorButton.FontWeight = 'bold';
                app.PatientPosteriorButton.Layout.Row = 2;
                app.PatientPosteriorButton.Layout.Column = 3;
                app.PatientPosteriorButton.Text = {'Patient'; 'Posterior'};

                % Create PatientInferiorButton
                app.PatientInferiorButton = uibutton(app.TranslateLayout, 'push');
                app.PatientInferiorButton.ButtonPushedFcn = createCallbackFcn(app, @JogPushed, true);
                app.PatientInferiorButton.Tag = '-S';
                app.PatientInferiorButton.WordWrap = 'on';
                app.PatientInferiorButton.FontSize = options.fontsize;
                app.PatientInferiorButton.FontWeight = 'bold';
                app.PatientInferiorButton.Layout.Row = 3;
                app.PatientInferiorButton.Layout.Column = 2;
                app.PatientInferiorButton.Text = {'Patient'; 'Inferior'};

                % Create PatientSuperiorButton
                app.PatientSuperiorButton = uibutton(app.TranslateLayout, 'push');
                app.PatientSuperiorButton.ButtonPushedFcn = createCallbackFcn(app, @JogPushed, true);
                app.PatientSuperiorButton.Tag = '+S';
                app.PatientSuperiorButton.WordWrap = 'on';
                app.PatientSuperiorButton.FontSize = options.fontsize;
                app.PatientSuperiorButton.FontWeight = 'bold';
                app.PatientSuperiorButton.Layout.Row = 3;
                app.PatientSuperiorButton.Layout.Column = 3;
                app.PatientSuperiorButton.Text = {'Patient'; 'Superior'};

                % Create TranslateIncrementmmLabel_2
                app.TranslateIncrementmmLabel_2 = uilabel(app.TranslateLayout);
                app.TranslateIncrementmmLabel_2.HorizontalAlignment = 'right';
                app.TranslateIncrementmmLabel_2.FontSize = options.fontsize;
                app.TranslateIncrementmmLabel_2.Layout.Row = 4;
                app.TranslateIncrementmmLabel_2.Layout.Column = [1 2];
                app.TranslateIncrementmmLabel_2.Text = 'Translate Increment (mm)';

                % Create TranslateIncrement
                app.TranslateIncrement = uieditfield(app.TranslateLayout, 'numeric');
                app.TranslateIncrement.Limits = [0.001 Inf];
                app.TranslateIncrement.FontSize = options.fontsize;
                app.TranslateIncrement.Layout.Row = 4;
                app.TranslateIncrement.Layout.Column = 3;
                app.TranslateIncrement.Value = 3;
            end
        end
    end

    % App creation and deletion
    methods (Access = public) 
        function app = TransWidget(options)           
            arguments
                options.parent = []
                options.trans fus.xdc.Transducer
                options.trans_handle
                options.skin_sph
                options.standoff = fus.xdc.Standoff();
                options.callback = function_handle.empty;
                options.fontsize = 20;
                options.tabs (1,:) string {mustBeMember(options.tabs, ["jog", "rotate", "orbit", "translate"])} = ["jog", "rotate", "orbit", "translate"]
                options.log fus.util.Logger = fus.util.Logger.get();
            end
            if isempty(options.parent)
                % Create UIFigure and hide until all components are created
                fig = uifigure('Visible', 'off');
                fig.Position = [100 100 494 340];
                fig.Name = 'MATLAB App';
                app.deletefcn = @fig.delete;
                % Create FigureLayout
                layout = uigridlayout(fig);
                layout.ColumnWidth = {'1x'};
                layout.RowHeight = {'1x'};
                layout.Padding = [0 0 0 0];
                options.parent = layout;
            end
            app.createComponents(options.parent, ...
                "fontsize", options.fontsize, ...
                "tabs", options.tabs)
            app.trans = options.trans;
            app.trans_handle = options.trans_handle;
            app.skin_sph = options.skin_sph;
            app.standoff = options.standoff;
            app.callback = options.callback;
            app.log = options.log; 
            set(ancestor(options.parent, "figure"), "visible", "on");
        end
    end
end