classdef SimTemperatureWidget < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure           matlab.ui.Figure
        TemperatureSlider  matlab.ui.control.Slider
    end

    % Callbacks that handle component events
    methods (Access = private)

        % Value changing function: TemperatureSlider
        function TemperatureSliderValueChanging(app, event)
            global SIM_TEMPERATURE
            changingValue = event.Value;
            SIM_TEMPERATURE = changingValue;
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)
            global SIM_TEMPERATURE
            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 313 42];
            app.UIFigure.Name = 'Simulate Temperature';

            % Create TemperatureSlider
            app.TemperatureSlider = uislider(app.UIFigure);
            app.TemperatureSlider.ValueChangingFcn = createCallbackFcn(app, @TemperatureSliderValueChanging, true);
            app.TemperatureSlider.Position = [11 30 291 3];
            %if exist('SIM_TEMPERATURE','var') && ~isempty(SIM_TEMPERATURE)
            SIM_TEMPERATURE = 27;
            app.TemperatureSlider.Value = SIM_TEMPERATURE;
            %else
            %    app.TemperatureSlider.Value = 27;
            %    
            %end
            
            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = SimTemperatureWidget

            runningApp = getRunningApp(app);

            % Check for running singleton app
            if isempty(runningApp)

                % Create UIFigure and components
                createComponents(app)

                % Register the app with App Designer
                registerApp(app, app.UIFigure)
            else

                % Focus the running singleton app
                figure(runningApp.UIFigure)

                app = runningApp;
            end

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