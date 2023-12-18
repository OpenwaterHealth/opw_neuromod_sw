classdef TableSelector < matlab.apps.AppBase
    
    properties (Access = public)
        UIFigure  matlab.ui.Figure
        Panel     matlab.ui.container.Panel
        UITable   matlab.ui.control.Table
        EditField       matlab.ui.control.EditField
        ApplyButton     matlab.ui.control.Button
        CancelButton matlab.ui.control.Button
        OKButton  matlab.ui.control.Button
        EditFieldLabel  matlab.ui.control.Label
    end
    
    
    properties (Access = private)
        is_child
        displaydata 
        selection_callback_id
        col_edit_index
        column_ids
        column_names
        sort_indices
        sort_index
        sort_ascend = true
        filter_mat
        filters
        display_row_index
    end
    
    properties (Access = public)
        selection_wait_for_ok
        selection_index
        data
    end
    
    methods (Access = private)
        
        function finish_selection(app)
            app.selection_wait_for_ok = false;
        end
        
        function set_row(app, row_index)
            bgs = uistyle('BackgroundColor',[1, 1, 1]);
            addStyle(app.UITable,bgs);  
            app.selection_index = row_index;
            if ~isempty(row_index)
                indices = app.sort_indices(all(app.filter_mat(app.sort_indices,:),2));
                app.display_row_index = find(indices == row_index,1);
                app.UITable.Selection = [];
                fgs = uistyle('BackgroundColor',[0.5, 0.7, 1]);
                addStyle(app.UITable,fgs,'row',app.display_row_index);
                app.OKButton.Enable = 'on';
            else
                app.OKButton.Enable = 'off';
            end
        end
        
        function sort_by(app, col_index)
            if isempty(app.sort_index)
                app.sort_ascend = true;
            else
                if col_index == app.sort_index
                    app.sort_ascend = ~app.sort_ascend;
                else
                    app.sort_ascend = true;
                end
            end
            col = app.column_ids{col_index};
            [~, ii] = sort(app.data.(col));
            if ~app.sort_ascend
                ii = ii(end:-1:1);
            end
            app.sort_indices = ii;
            app.sort_index = col_index;
            app.update_table();
            app.UITable.Selection = [];
        end
        
        function update_table(app)
            display_names = app.column_names;
            if ~isempty(app.sort_index)
                if app.sort_ascend
                    icon = char(compose("\x23EB"));
                else
                    icon = char(compose("\x23EC"));
                end
                display_names{app.sort_index} = sprintf('%s %s',icon, display_names{app.sort_index});
            end
            sanitize = @(x)strrep(x,'|',char(compose("\xFFE8")));
            for i = 1:length(app.column_ids)
                filt = app.filters.(app.column_ids{i});
                if ~isempty(filt)
                    display_names{i} = sprintf('%s "%s"',display_names{i}, sanitize(filt));
                end
            end
            app.UITable.ColumnName = display_names;
            indices = app.sort_indices(all(app.filter_mat(app.sort_indices,:),2));
            table_data = app.displaydata(indices,:);
            app.UITable.Data = table_data;
            if ~isempty(app.selection_index) && any(indices==app.selection_index)
                app.set_row(app.selection_index)
            else
                app.set_row([]);
            end

        end
        
        function set_filter(app, col_index, filter_text)
            display_column_ids = app.displaydata.Properties.VariableNames;
            app.filters.(app.column_ids{col_index}) = filter_text;
            if isempty(filter_text)
                filter_text = '.*';
            end
            col_data = app.displaydata.(display_column_ids{col_index});
            matches = ~cellfun(@isempty, regexp(col_data, filter_text, 'once'));
            app.filter_mat(:,col_index) = matches;
            app.update_table();
        end
        
        function edit_filter(app, col_index)
            app.col_edit_index = col_index;
            app.EditField.Value = app.filters.(app.column_ids{col_index});
            app.EditField.Visible = true;
            app.UITable.Enable = 'off';
            app.OKButton.Enable = 'off';
            app.EditFieldLabel.Text = sprintf('Filter %s:', app.column_names{col_index});
            app.ApplyButton.Visible = true;
            app.EditFieldLabel.Visible = true;
            drawnow;
            robot = java.awt.Robot;
            for i = 1
                robot.keyPress(java.awt.event.KeyEvent.VK_TAB);
                pause(.0001)
                robot.keyRelease(java.awt.event.KeyEvent.VK_TAB);
            end
            app.UITable.Selection = [];
        end
    end
    
    % Callbacks that handle component events
    methods (Access = private)
        % Button pushed function: OKButton
        function OKButtonPushed(app, event)
            app.finish_selection()
        end
        
        function CancelButtonPushed(app, event)
            app.selection_index = [];
            app.finish_selection();
        end
        
        function ApplyButtonPushed(app, event)
            if size(app.UITable.Data,1) > 0
                app.EditFieldLabel.Visible = false;
                app.EditField.Visible = false;
                app.ApplyButton.Visible = false;
                app.UITable.Enable = 'on';
            end
        end
        
        function EditFieldValueChanging(app, event)
            changingValue = event.Value;
            app.set_filter(app.col_edit_index, changingValue);
        end
        
        function UITableKeyPress(app, event)
            % Check for the user pressing "enter" in the table
            key = event.Key;
            switch key
                case 'return'
                    if ~isempty(app.selection_index)
                        app.finish_selection();
                    end
            end
        end
        
        % Cell selection callback: UITable
        function UITableCellSelection(app, event)
            rid = rand; 
            app.selection_callback_id = rid;
            indices = event.Indices;
            if isempty(indices) % this may not be necessary
                app.OKButton.Enable = 'off';
                return
            end
            t = tic;
            while (toc(t) < 0.25) && (app.selection_callback_id == rid)
                pause(0.01);
            end
            if (app.selection_callback_id ~= rid)
                % Another callback has interrupted this one
                return
            end
            seltype = app.UIFigure.SelectionType;
            column_select = (size(indices,1)>1) && (size(indices,1) == size(app.UITable.Data,1)) && ~any(diff(indices(:,2)));
            switch seltype 
                case 'open' % Double Click
                    if column_select
                        app.edit_filter(indices(1,2));
                    else
                        sorted_indices = app.sort_indices(all(app.filter_mat(app.sort_indices,:),2));
                        if ~isempty(app.display_row_index) && app.display_row_index < max(indices(:,1))
                            app.selection_index = sorted_indices(indices(end,1));
                        else
                            app.selection_index = sorted_indices(indices(1,1));
                        end
                        app.finish_selection()
                    end
                otherwise
                    if column_select
                        app.sort_by(indices(1,2));
                    else
                        sorted_indices = app.sort_indices(all(app.filter_mat(app.sort_indices,:),2));
                        if ~isempty(app.display_row_index) && app.display_row_index < max(indices(:,1))
                            app.set_row(sorted_indices(indices(end,1)))
                        else
                            app.set_row(sorted_indices(indices(1,1)))
                        end


                    end
            end
        end
    end


    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = TableSelector(data, options)
            arguments
                data table
                options.display_data = []
                options.column_names = []
                options.fig_position (1,4) double = [100, 100, 640, 480]
                options.title string =  "Make a Selection"
                options.position (1,4) double = [0, 0, 1, 1]
                options.font_size (1,1) double {mustBeInteger, mustBePositive} = 12
                options.table_font_size = []
                options.parent = -1
            end
            app.data = data;            
            if isempty(options.display_data)
                app.displaydata = data;
            else
                app.displaydata = options.display_data;
            end
            app.column_ids = cellfun(@genvarname, app.data.Properties.VariableNames, "UniformOutput", false);
            if isempty(options.column_names)
                app.column_names = app.data.Properties.VariableNames;
            else
                app.column_names = options.column_names;
            end
            %app.data.Properties.VariableNames = app.column_ids;
            app.filter_mat = true(size(app.data));
            for i = 1:length(app.column_ids)
                app.filters.(app.column_ids{i}) = '';
            end
            app.selection_index = [];
            app.sort_indices = [1:size(data,1)];
            app.selection_wait_for_ok = true;

            if ishandle(options.parent)
                app.UIFigure = options.parent;
                panel_title = options.title;
                app.is_child = true;
            else
            % Create UIFigure and hide until all components are created
                app.UIFigure = uifigure('Visible', 'off');
                app.UIFigure.Position = options.fig_position;
                app.UIFigure.Name = options.title;
                panel_title = [];
                app.is_child = false;
                options.position = [0, 0, 1, 1];
            end
            
            if isempty(options.table_font_size)
                options.table_font_size = options.font_size;
            end
            
            % Create Panel
            fpos = app.UIFigure.Position;         
            app.Panel = uipanel(app.UIFigure);
            if ishandle(options.parent)
                app.Panel.Title = panel_title;
            end
            app.Panel.FontSize = options.font_size;
            app.Panel.Position = round([...
                fpos(3)*options.position(1), ...
                fpos(4)*options.position(2), ...
                fpos(3)*options.position(3), ...
                fpos(4)*options.position(4)]);
            
            % Create OKButton
            app.OKButton = uibutton(app.Panel, 'push');
            app.OKButton.ButtonPushedFcn = createCallbackFcn(app, @OKButtonPushed, true);
            ppos = app.Panel.Position;
            margin = 5;
            bsz = [3, 1]*(options.font_size + 10);
            app.OKButton.Position = round([...
                ppos(3)-bsz(1)-margin, ...
                margin, ...
                bsz(1), ...
                bsz(2)]);
            app.OKButton.Text = 'OK';
            app.OKButton.FontSize = options.font_size;
            app.OKButton.Enable = 'off';

            % Create CancelButton
            app.CancelButton = uibutton(app.Panel, 'push');
            app.CancelButton.ButtonPushedFcn = createCallbackFcn(app, @CancelButtonPushed, true);
            ppos = app.Panel.Position;
            app.CancelButton.Position = round([...
                ppos(3)-bsz(1)*2-margin*2, ...
                margin, ...
                bsz(1), ...
                bsz(2)]);
            app.CancelButton.Text = 'Cancel';
            app.CancelButton.FontSize = options.font_size;

             % Create EditFieldLabel
            app.EditFieldLabel = uilabel(app.Panel);
            app.EditFieldLabel.HorizontalAlignment = 'right';
            app.EditFieldLabel.FontSize = options.font_size;
            elsz = [5, 1]*[options.font_size+10];
            app.EditFieldLabel.Position = round([...
                margin, ...
                margin, ...
                elsz(1), ...
                elsz(2)]);
            app.EditFieldLabel.Text = 'Edit Field';
            app.EditFieldLabel.Visible = false;

            % Create UITable
            app.UITable = uitable(app.Panel);
            app.UITable.Data = app.displaydata;
            app.UITable.ColumnName = app.column_names;
            app.UITable.RowName = {};
            app.UITable.FontSize = options.table_font_size;
            app.UITable.CellSelectionCallback = createCallbackFcn(app, @UITableCellSelection, true);          
            app.UITable.KeyPressFcn = createCallbackFcn(app, @UITableKeyPress, true);
            app.UITable.Position = round([...
                margin, ...
                bsz(2) + 2*margin, ...
                ppos(3) - 2*margin, ...
                ppos(4) - (bsz(2)+(3*margin)+(options.font_size+10))...
                ]);
           
            % Create EditField
            esz = [5, 1]*[options.font_size+10];
            app.EditField = uieditfield(app.Panel, 'text');
            app.EditField.ValueChangingFcn = createCallbackFcn(app, @EditFieldValueChanging, true);
            app.EditField.ValueChangedFcn = createCallbackFcn(app, @ApplyButtonPushed, true);
            app.EditField.Position = round([...
                margin*2+elsz(1), ...
                margin, ...
                esz(1), ...
                esz(2)]);
            app.EditField.Visible = false;

            % Create ApplyButton
            app.ApplyButton = uibutton(app.Panel, 'push');
            app.ApplyButton.Position = round([...
                margin*3+elsz(1)+esz(1), ...
                margin, ...
                bsz(1), ...
                bsz(2)]);
            app.ApplyButton.Text = 'Apply';
            app.ApplyButton.ButtonPushedFcn = createCallbackFcn(app, @ApplyButtonPushed, true);
            app.ApplyButton.Visible = false;            
            
            % Show the figure after all components are created
            figure(app.UIFigure)
            app.UIFigure.Visible = 'on';
            if size(data,1) == 1
                app.set_row(1)
            end
            
            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)
            % Delete UIFigure when app is deleted
            if app.is_child
                delete(app.Panel)
            else
                delete(app.UIFigure)
            end
        end
    end
    
    methods (Static)
        function row = select(data, options)
            arguments
                data table
                options.display_data = []
                options.column_names (1,:) string = string.empty
                options.fig_position (1,4) double = [100, 100, 640, 480]
                options.title string =  "Make a Selection"
                options.position (1,4) double = [0, 0, 1, 1]
                options.font_size (1,1) double {mustBeInteger, mustBePositive} = 12
                options.table_font_size = []
                options.parent = -1
                options.graphical logical = true
            end
            if options.graphical
                args = fus.util.struct2args(rmfield(options, 'graphical'));
                ts = fus.util.TableSelector(data, args{:});
                while ishandle(ts.UIFigure) && ts.selection_wait_for_ok
                    pause(0.1)
                end
                if ~ishandle(ts.UIFigure)
                    row_index = [];
                else
                    row_index = ts.selection_index;
                end
                row = ts.data(row_index,:);
                delete(ts)
            else
                 if ~isempty(options.display_data)
                     display_data = options.display_data;
                 else
                     display_data = data;
                 end
                 if ~isempty(options.column_names)
                     display_data.Properties.VariableNames = options.column_names;
                 end
                 row_index = fus.util.TableSelector.cmd_select(display_data);
                 row = data(row_index,:);
            end
        end
    end
    
    methods (Static, Access=private)
        function selected_row = cmd_select(tab)
            selected_row = 1;
            fus.util.TableSelector.disp_tab(tab, selected_row, false);
            f = figure('Visible','off', 'Position', [0 0 1 1], 'NumberTitle', 'off', 'MenuBar', 'none', 'Toolbar','None');
            enter = false;
            while ~enter
                waitforbuttonpress
                val = double(get(f,'CurrentCharacter'));
                switch val
                    case 30
                        selected_row = max(1,selected_row-1);
                        fus.util.TableSelector.disp_tab(tab, selected_row, true);
                    case 31
                        selected_row = min(size(tab,1),selected_row+1);
                        fus.util.TableSelector.disp_tab(tab, selected_row, true);
                    case 13
                        close(f);
                        enter = true;
                    case 27
                        close(f)
                        selected_row = [];
                        enter = true;
                end
            end
        end
        
        function disp_tab(tab, selected_row, erase)
            lines = splitlines(matlab.unittest.diagnostics.ConstraintDiagnostic.getDisplayableString(tab));
            rows = lines(6:end);
            header = lines(3:4);
            s = '';
            s = [s sprintf(' %s %s\n',sprintf('<strong>sel</strong>'), header{1})];
            s = [s sprintf('_____%s\n', header{2})];
            s = [s sprintf('\n')];
            for i = 1:length(rows)
                if i == selected_row
                    mark = '[ * ]';
                else
                    mark = '[   ]';
                end
                s = [s sprintf('%s%s\n', mark, rows{i})];
            end
            if erase
                n = sum(6+cellfun(@length, rows)) + sum(6+cellfun(@length, header)) - 34*(size(tab,2)) + 1;
                %n = length(s);
                fprintf([repmat('\b', 1, n) '%s'], s)
            else
                fprintf('%s', s);
            end

        end
    end
end