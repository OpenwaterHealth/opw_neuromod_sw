classdef ColorMapper_UI < fus.DataClass
    % COLORMAPPER_UI - A UI for visualizing and editing a fus.ColorMapper
    properties
        axes % axes or uiaxes to draw in
        cmap (1,1) fus.ColorMapper % colormap to visualize
        range (1,2) double % scalar range to draw
        imhandle % handle to the image object
        alpha_roi (1,1) images.roi.Line % handle to the alpha slider
        color_roi (1,1) images.roi.Line % handle to the color slider
        alim_labels (1,:) matlab.graphics.primitive.Text % handles to the alpha labels
        clim_labels (1,:) matlab.graphics.primitive.Text % handles to the color labels
        on_update function_handle % function to call when the colormap is updated
    end
    properties (Access=protected)
        listeners
        label_format
    end
    methods
        function self = ColorMapper_UI(cmap, options)
            % COLORMAPPER_UI - A UI for visualizing and editing a ColorMapper
            % cm = fus.ui.ColorMapper_UI(cmap, "param", value, ...)
            %
            % Inputs:
            %   cmap (1,1) fus.ColorMapper
            %
            % Optional Parameters:
            %   'axes' (axes or uiaxes): to draw in
            %   'range' (1x2 double): scalar range to draw.
            %   'fontsize' (double): font size. Default: 12
            %   'fontweight' (string): font weight. Default: "Bold"
            %   'markersize' (double): size of the markers. Default: 12
            %   'fg_color' (1x3 double): foreground color. Default: [0,0,0]
            %   'bg_color' (1x3 double): background color. Default: [1,1,1]
            %   'margin_width_px' (double): width of the margins in pixels. Default: 30
            %   'slider_offset' (double): offset of the sliders from the edge of the axes. Default: 0
            %   'label_format' (string): format string for the labels. Default: "%0.4g"
            %   'label_side' (string): side of the labels. Default: "inside"
            %   'label_offset' (double): offset of the labels from the edge of the axes. Default: 0.05
            %   'on_update' (function_handle): function to call when the colormap is updated
            arguments
                cmap (1,1) fus.ColorMapper
                options.axes
                options.range (1,:) double
                options.fontsize (1,1) double {mustBeInteger, mustBePositive} = 12
                options.fontweight (1,1) string {mustBeMember(options.fontweight, ["Normal", "Bold"])} = "Bold"
                options.markersize (1,1) double {mustBeInteger, mustBePositive} = 12
                options.fg_color (1,3) double {mustBeInRange(options.fg_color, 0, 1)};
                options.bg_color (1,3) double {mustBeInRange(options.bg_color, 0, 1)};
                options.margin_width_px (1,1) double {mustBeInteger} = 30;
                options.slider_offset (1,1) double = 0;
                options.label_format (1,1) string = "%0.4g"
                options.label_side (1,1) string {mustBeMember(options.label_side, ["outside", "inside"])} = "inside"
                options.label_offset (1,1) double = 0.05;
                options.on_update function_handle = function_handle.empty
            end
            if isfield(options, "bg_color") && isfield(options, "fg_color")
               fg_color = options.fg_color;
               bg_color = options.bg_color;
            elseif isfield(options, "bg_color")
                fg_color = rgb2gray(1-options.bg_color);
                bg_color = options.bg_color;
            elseif isfield(options, "fg_color")
                fg_color = options.fg_color;
                bg_color = rgb2gray(1-options.fg_color);
            else
                fg_color = [0,0,0];
                bg_color = [1,1,1];
            end
            if isfield(options, "axes")
                self.axes = options.axes;
                cla(self.axes);
            else
                fig = uifigure();
                frame = uipanel(fig, "Units", "normalized", "Position", [0,0,1,1]);
                grid = uigridlayout(frame, [1 3], "BackgroundColor", bg_color);
                grid.ColumnWidth = {options.margin_width_px, '1x', options.margin_width_px};
                self.axes = uiaxes(grid);
                self.axes.Layout.Column = 2;
            end
            self.cmap = cmap;
            if isfield(options, "range") && ~isempty(options.range)
                self.range = [...
                    min([self.cmap.alim_in(1), self.cmap.clim_in(1), self.range(1)]), ...
                    max([self.cmap.alim_in(2), self.cmap.clim_in(2), self.range(2)])];
            else
                self.range = [...
                    min(self.cmap.alim_in(1), self.cmap.clim_in(1)), ...
                    max(self.cmap.alim_in(2), self.cmap.clim_in(2))];
            end
            self.label_format = options.label_format;
            self.imhandle = image(...
                self.axes, ...
                "XData", [-1/3,1/3],...
                "YData", self.range,...
                "CData",self.cmap.get_colormap(...
                    "clim", self.range, ...
                    "N", size(self.cmap.cmap,1)), ...
                "AlphaData",self.cmap.get_alphamap(...
                    "alim", self.range, ...
                    "N", size(self.cmap.amap,1)),...
                "HitTest", "off");
            set(self.axes, ...
                "Color","k",...
                "YAxisLocation", "right",...
                "XTick", [-1, 1], ...
                "XLim", [-1, 1], ...
                "YLim", self.range, ...
                "XTickLabels", ["Opacity", "Color"], ...
                "HitTest", "off", ...
                "YColor", fg_color, ...
                "XColor", fg_color, ...
                "Box", "on",...
                "Clipping", "off", ...
                "FontSize", options.fontsize, ...
                "FontWeight", options.fontweight)
            disableDefaultInteractivity(self.axes) 
            axtoolbar(self.axes, {});
            self.alpha_roi = images.roi.Line(...
                self.axes, ...
                "Position", [-(1+options.slider_offset), self.cmap.alim_in(1); -(1+options.slider_offset) self.cmap.alim_in(2)],...
                "DrawingArea", [-(1 + options.slider_offset), self.range(1), 0, diff(self.range)], ...
                "MarkerSize", options.markersize);
            self.color_roi = images.roi.Line(...
                self.axes, ...
                "Position", [1+options.slider_offset, self.cmap.clim_in(1); 1+options.slider_offset self.cmap.clim_in(2)],...
                "DrawingArea", [1+options.slider_offset, self.range(1), 0, diff(self.range)], ...
                "MarkerSize", options.markersize);
            label_props = {...
                "Color", fg_color, ...
                "BackgroundColor", [bg_color 0.5], ...
                "VerticalAlignment", "middle", ...
                "FontSize", options.fontsize,...
                "FontWeight", options.fontweight, ...
                "Margin", 1, ...
                "HitTest", "off"};
            for i = 1:2
                switch options.label_side
                    case "inside"
                        pol = -1;
                        ha_l = "left";
                        ha_r = "right";
                    case "outside"
                        pol = 1;
                        ha_l = "right";
                        ha_r = "left";
                end
                self.alim_labels(i) = text(...
                    self.axes, ...
                    -(1+options.slider_offset+pol*options.label_offset*2), ...
                    self.cmap.alim_in(i), ...
                    sprintf(self.label_format, self.cmap.alim_in(i)),...
                    "HorizontalAlignment", ha_l,...
                    label_props{:});
                self.clim_labels(i) = text(...
                    self.axes, ...
                    (1+options.slider_offset+pol*options.label_offset*2), ...
                    self.cmap.clim_in(i), ...
                    sprintf(self.label_format, self.cmap.clim_in(i)),...
                    "HorizontalAlignment", ha_r,...
                    label_props{:});
            end
            self.on_update = options.on_update;
            self.listeners = [...
                addlistener(self.alpha_roi, "ROIMoved", @self.update), ...
                addlistener(self.color_roi, "ROIMoved", @self.update)];
        end
        
        function set_range(self, range)
            % SET_RANGE Set the range of the sliders
            %   cm.set_range(range)
            %
            % Inputs:
            %   range (1x2 double): 2-element vector of the form [min, max]
            %       specifying the range of the sliders
            self.range = range;
            set(self.axes, "YLim", self.range);
            self.color_roi.Position(:,2) = [max(self.cmap.clim_in(1), range(1)); min(self.cmap.clim_in(2), range(2))];
            self.alpha_roi.Position(:,2) = [max(self.cmap.alim_in(1), range(1)); min(self.cmap.alim_in(2), range(2))];
            self.color_roi.DrawingArea(1,[2 4]) = [self.range(1), diff(self.range)];
            self.alpha_roi.DrawingArea(1,[2 4]) = [self.range(1), diff(self.range)];
            self.update();
        end
        
        function update(self, ~, ~)
            % UPDATE Update the colormap
            %   cm.update()
            % UPDATE updates the colormap based on the slider positions, 
            % and calls the on_update callback function if it is defined 
            % (to update images using the colormap, for example)
            alpha_pos = self.alpha_roi.Position;
            color_pos = self.color_roi.Position;
            self.cmap.alim_in = sort(alpha_pos(:,2));
            self.cmap.clim_in = sort(color_pos(:,2));
            self.alpha_roi.Position(:, 2) = self.cmap.alim_in;
            self.color_roi.Position(:, 2) = self.cmap.clim_in;
            adata = self.cmap.get_alphamap(...
                    "alim", self.range, ...
                    "N", size(self.cmap.amap,1));
            cdata = self.cmap.get_colormap(...
                    "clim", self.range, ...
                    "N", size(self.cmap.cmap,1));
            set(self.imhandle,"CData", cdata, "AlphaData", adata, "YData",self.range);
            for i = 1:2
                self.alim_labels(i).Position(2) = self.cmap.alim_in(i);
                self.alim_labels(i).String = sprintf(self.label_format, self.cmap.alim_in(i));
                self.clim_labels(i).Position(2) = self.cmap.clim_in(i);
                self.clim_labels(i).String = sprintf(self.label_format, self.cmap.clim_in(i));
            end
            if ~isempty(self.on_update)
                self.on_update();
            end
        end
    end
end

