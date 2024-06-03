classdef Solution < fus.DataClass
    % TreatmentSolution Treatment solution class.
    %   solution = fus.treatment.Solution("param", value, ...) 
    properties
        plan_id (1,1) string % Plan ID
        target_id (1,1) string  % Target ID
        created_on datetime = datetime % Date created
        description (1,1) string = "" % Description
        transducer fus.xdc.Transducer % Transducer
        delays double % Delay times (s)
        apodizations double % Apodization values
        pulse (1,1) fus.Pulse % Pulse specification
        sequence (1,1) fus.Sequence % Sequence specification
        focus (1,:) fus.Point % Focus points
    end
    
    methods
        function self = Solution(options)
            % TREATMENTSOLUTION Constructor
            %  solution = fus.treatment.Solution("param", value, ...)
            % TREATMENTSOLUTION creates a new treatment solution
            % object. A treatment solution is the information that 
            % a system needs to deliver the requested ultrasound
            % energy (as specified in the plan) to a particular
            % target in a particular volume of tissue. 
            %
            % Optional Parameters:
            %   'plan_id' (string) - Plan ID
            %   'target_id' (string) - Target ID
            %   'created_on' (datetime) - Date created
            %   'description' (string) - Description
            %   'transducer' (fus.xdc.Transducer) - Transducer
            %   'delays' (double) - Delay times (s)
            %   'apodizations' (double) - Apodization values
            %   'pulse' (fus.Pulse) - Pulse specification
            %   'sequence' (fus.Sequence) - Sequence specification
            %   'focus' (fus.Point) - Focus points
            % 
            % Returns:
            %   solution (fus.treatment.Solution) - Treatment solution
            arguments
                options.?fus.treatment.Solution
            end
            self.parse_props(options);
        end
        
        function analysis = analyze(self, output, options)
            % ANALYZE Analyze treatment solution
            %   analysis = solution.analyze(output, "param", value, ...)
            % ANALYZE analyzes the treatment solution and returns
            % a struct containing the results of the analysis.
            arguments
                self (1,1) fus.treatment.Solution
                output (1,1) struct
                options.standoff_sound_speed (1,1) double {mustBePositive} = 1500
                options.standoff_density (1,1) double {mustBePositive} = 1000
                options.ref_sound_speed (1,1) double {mustBePositive} = 1500
                options.ref_density (1,1) double {mustBePositive} = 1000
                options.focus_dia (1,1) double {mustBePositive} = 0.5
                options.mainlobe_aspect_ratio (1,3) double {mustBeInteger, mustBePositive} = [1 1 5]
                options.mainlobe_radius (1,1) double {mustBePositive} = 2.5e-3
                options.beamwidth_radius (1,1) double {mustBePositive} = 5e-3
                options.sidelobe_radius (1,1) double = 3e-3
                options.sidelobe_zmin (1,1) = 1e-3
            end
            dt = 1/(self.pulse.frequency*20);
            t = self.pulse.calc_time(dt);
            input_signal = self.pulse.calc_pulse(t);
            coords = output.pnp.get_coords;
            if isnan(options.sidelobe_radius)
                options.sidelobe_radius = options.mainlobe_radius;
            end
            analysis = struct();
            pnp_MPa = output.pnp.rescale_data('MPa');
            intensity_Wcm2 = output.intensity.rescale_data('W/cm2');
            pulsetrain_dutycycle = min(1,self.pulse.duration/self.sequence.pulse_interval);
            treatment_dutycycle = min(1,(self.sequence.pulse_count * self.sequence.pulse_interval) / self.sequence.pulse_train_interval);
            standoff_Z = options.standoff_density * options.standoff_sound_speed;
            c_tic = 40e-3; % W cm-1
            A_cm = self.transducer.get_area("units","cm");
            d_eq_cm = sqrt(4*A_cm/pi); % [cm] equivalent diameter of transducer
            ele_sizes_cm2 = self.transducer.elements.get_area("units", "cm");
            z = coords.ndgrid(dim="ax");
            z_mask = z{1}>=options.sidelobe_zmin;
            pulse_seq = mod((1:self.sequence.pulse_count)-1, self.num_foci)+1;
            counts = zeros(1,1,1,self.num_foci);
            for i = 1:self.num_foci
                counts(1,1,1,i) = sum(pulse_seq==i);
            end
            isppa_avg = sum(cell2mat(reshape({intensity_Wcm2.data},1,1,1,[])).*counts,4)/sum(counts);
            i_ta_mWcm2 = isppa_avg*pulsetrain_dutycycle*treatment_dutycycle*1e3;
            for focus_index = 1:self.num_foci
                foc = self.focus(focus_index);
                if ~any(self.apodizations(focus_index,:))
                    analysis.mainlobe_pnp_MPa(focus_index) = 0;
                    analysis.mainlobe_isppa_Wcm2(focus_index) = 0;
                    analysis.mainlobe_ispta_mWcm2(focus_index) = 0;
                    analysis.beamwidth_lat_3dB_mm = nan;
                    analysis.beamwidth_ax_3dB_mm = nan;
                    analysis.beamwidth_lat_6dB_mm = nan;
                    analysis.beamwidth_ax_6dB_mm = nan;
                    analysis.sidelobe_pnp_MPa(focus_index) = 0;
                    analysis.sidelobe_isppa_Wcm2(focus_index) = 0;
                    analysis.global_pnp_MPa(focus_index) = 0;
                    analysis.global_isppa_Wcm2(focus_index) = 0;
                    analysis.p0_Pa(focus_index) = 0;
                    power_W(focus_index) = 0;
                    TIC(focus_index) = 0;
                    continue
                end
                for i = 1:self.transducer.numelements
                    apod_signal = input_signal*self.apodizations(focus_index, i);
                    output_signal{i} = self.transducer.elements(i).calc_output(apod_signal, dt);
                end
                p0_Pa = cellfun(@max, output_signal);
                mainlobe_mask = fus.bf.mask_focus(...
                    coords, ...
                    foc, ...
                    options.mainlobe_radius, ...
                    operation = "<=", ...
                    units="m", ...
                    aspect_ratio=options.mainlobe_aspect_ratio);
                sidelobe_mask = fus.bf.mask_focus(...
                    coords, ...
                    foc, ...
                    options.sidelobe_radius, ...
                    operation = ">=", ...
                    zmin=options.sidelobe_zmin, ...
                    units="m", ...
                    aspect_ratio=options.mainlobe_aspect_ratio);
                beamwidth_mask = fus.bf.mask_focus(...
                    coords, ...
                    foc, ...
                    options.beamwidth_radius, ...
                    operation = "<=", ...
                    zmin=options.sidelobe_zmin, ...
                    units="m", ...
                    aspect_ratio=options.mainlobe_aspect_ratio);
                pk = max(pnp_MPa(focus_index).data .* mainlobe_mask, [], "all");
                analysis.mainlobe_pnp_MPa(focus_index) = pk;
                thresh_m3dB = pk*10^(-3/20);
                thresh_m6dB = pk*10^(-6/20);
                bw3xy = fus.bf.get_beamwidth(pnp_MPa(focus_index), foc, thresh_m3dB, "dims", [1, 2], "mask", beamwidth_mask, "units", "mm");
                bw3z = fus.bf.get_beamwidth(pnp_MPa(focus_index), foc, thresh_m3dB, "dims", [3], "mask", beamwidth_mask, "units", "mm");
                bw6xy = fus.bf.get_beamwidth(pnp_MPa(focus_index), foc, thresh_m6dB, "dims", [1, 2], "mask", beamwidth_mask, "units", "mm");
                bw6z = fus.bf.get_beamwidth(pnp_MPa(focus_index), foc, thresh_m6dB, "dims", [3], "mask", beamwidth_mask, "units", "mm");
                analysis.mainlobe_isppa_Wcm2(focus_index) = max(intensity_Wcm2(focus_index).data .* mainlobe_mask, [], "all");
                analysis.mainlobe_ispta_mWcm2(focus_index) = max(i_ta_mWcm2 .* mainlobe_mask, [], "all");
                analysis.beamwidth_lat_3dB_mm = bw3xy.beamwidth;
                analysis.beamwidth_ax_3dB_mm = bw3z.beamwidth;
                analysis.beamwidth_lat_6dB_mm = bw6xy.beamwidth;
                analysis.beamwidth_ax_6dB_mm = bw6z.beamwidth;
                analysis.sidelobe_pnp_MPa(focus_index) = max(pnp_MPa(focus_index).data .* sidelobe_mask, [], "all");
                analysis.sidelobe_isppa_Wcm2(focus_index) = max(intensity_Wcm2(focus_index).data .* sidelobe_mask, [], "all");
                analysis.global_pnp_MPa(focus_index) = max(pnp_MPa(focus_index).data .* z_mask, [], "all");
                analysis.global_isppa_Wcm2(focus_index) = max(intensity_Wcm2(focus_index).data .* z_mask, [], "all");
                i0_Wcm2 = (p0_Pa.^2 ./ (2*standoff_Z)) * 1e-4;
                i0ta_Wcm2 = i0_Wcm2*pulsetrain_dutycycle*treatment_dutycycle;
                power_W(focus_index) = mean(sum(i0ta_Wcm2.*ele_sizes_cm2.*self.apodizations(focus_index,:)));
                TIC(focus_index) = power_W(focus_index)/d_eq_cm/c_tic;                
                analysis.p0_Pa(focus_index) = max(p0_Pa);
            end
            analysis.TIC = mean(TIC);
            analysis.power_W = mean(power_W);
            analysis.MI = analysis.mainlobe_pnp_MPa/sqrt(self.pulse.frequency*1e-6);
            ita = self.get_ita(output);
            analysis.global_ispta_mWcm2 = max(ita.data.*z_mask, [], "all");
        end

        function solution = by_target(self, target_id)
            arguments 
                self fus.treatment.Solution
                target_id (1,1) string {mustBeValidVariableName}
            end
            target_ids = [self.target_id];
            solution = self(ismember(target_ids, target_id));
        end
        
        function solution = by_plan(self, plan_id)
            arguments 
                self fus.treatment.Solution
                plan_id (1,1) string {mustBeValidVariableName}
            end
            plan_ids = [self.plan_id];
            solution = self(ismember(plan_ids, plan_id));
        end 
        
        function ita = get_ita(self, output, options)
            arguments
                self fus.treatment.Solution
                output struct
                options.units = "mW/cm^2"
            end
            intensity_scaled = output.intensity.rescale_data(options.units);
            pulsetrain_dutycycle = min(1,self.pulse.duration/self.sequence.pulse_interval);
            treatment_dutycycle = min(1,(self.sequence.pulse_count * self.sequence.pulse_interval) / self.sequence.pulse_train_interval);
            pulse_seq = mod((1:self.sequence.pulse_count)-1, self.num_foci)+1;
            counts = zeros(1,1,1,self.num_foci);
            for i = 1:self.num_foci
                counts(1,1,1,i) = sum(pulse_seq==i);
            end
            ita = intensity_scaled(1).copy();
            isppa_avg = sum(cell2mat(reshape({intensity_scaled.data},1,1,1,[])).*counts,4)/sum(counts);
            ita.data = isppa_avg*pulsetrain_dutycycle*treatment_dutycycle;
        end
        
        function tab = get_table(self, analysis, options)
            arguments
                self (1,1) fus.treatment.Solution
                analysis (1,1) struct
                options.agg = "max";
            end
            switch options.agg
                case "max"
                    agg = @max;
                case "none"
                    agg = @(x)x;
                otherwise
                    error("Bad aggregation function");
            end
                        
            tab = struct2table([...
                struct("Name", "PNP", ...
                       "Value", join(arrayfun(@(x)sprintf("%0.0f", x), agg(analysis.mainlobe_pnp_MPa*1e3)), ", "), ...
                       "Units", "kPa"), ...     
                struct("Name", "L_lat_3dB", ...
                       "Value", sprintf("%0.1f", agg(analysis.beamwidth_lat_3dB_mm)), ...
                       "Units", "mm"), ...
                struct("Name", "L_ax_3dB", ...
                       "Value", sprintf("%0.1f", agg(analysis.beamwidth_ax_3dB_mm)), ...
                       "Units", "mm"), ...
                struct("Name", "L_lat_6dB", ...
                       "Value", sprintf("%0.1f", agg(analysis.beamwidth_lat_6dB_mm)), ...
                       "Units", "mm"), ...
                struct("Name", "L_ax_6dB", ...
                       "Value", sprintf("%0.1f", agg(analysis.beamwidth_ax_6dB_mm)), ...
                       "Units", "mm"), ...
                struct("Name", "ISPPA", ...
                       "Value", join(arrayfun(@(x)sprintf("%0.3g", x), agg(analysis.mainlobe_isppa_Wcm2)), ", "), ...
                       "Units", "W/cm^2"), ...
                struct("Name", "ISPTA", ...
                       "Value", sprintf("%0.1f", analysis.global_ispta_mWcm2), ...
                       "Units", "mW/cm^2"), ...
                struct("Name", "TIC", ...
                      "Value", sprintf("%0.2f", mean(analysis.TIC)), ...
                      "Units", ""), ...
                struct("Name", "MI", ...
                      "Value", join(arrayfun(@(x)sprintf("%0.2f", x), agg(analysis.MI)), ", "), ...
                      "Units", ""), ...
                struct("Name", "Voltage", ...
                      "Value", sprintf("%0.1f", self.pulse.amplitude), ...
                      "Units", "V")]);   
                  
        end
        
        function nfoc = num_foci(self)
            arguments
                self fus.treatment.Solution
            end
            nfoc = length(self.focus);
        end
        
        function [output, inputs] = simulate(self, params, options)
            arguments
                self fus.treatment.Solution
                params (1,:) fus.Volume
                options.sim_options struct = struct()
                options.analysis_options struct = struct()
                options.progressbar (1,1) logical = true
                options.parent = -1;
                options.log fus.util.Logger = fus.util.Logger.get()
            end
            if ~isfield(options.sim_options, "source_strength")
                options.sim_options.source_strength = self.pulse.amplitude;
            end
            if ~isfield(options.sim_options, "tone_burst_freq")
                options.sim_options.tone_burst_freq = self.pulse.frequency;
            end
            if ~isfield(options.sim_options, "tone_burst_cycles")
                options.sim_options.tone_burst_cycles = self.pulse.duration*self.pulse.frequency;
            end
            if ~isfield(options.sim_options,"sound_speed_ref")
                options.sim_options.sound_speed_ref = params.by_id("sound_speed").attrs.ref_material.sound_speed;
            end
            options.sim_options.record = ["p_min"];
            args = fus.util.struct2args(options.sim_options);
            if options.progressbar;p = fus.util.ProgressBar("title", "Simulating...", "figure", options.parent, "N", length(self.focus));end
            output = struct();
            for i = 1:length(self.focus)
                if options.progressbar
                    p.update(p.x+1, sprintf("Simulating Focus %d/%d...", i, length(self.focus)));
                end
                [pnp, inputs(i)] = fus.sim.run_acoustic_sim(self.transducer, params, self.delays(i,:), self.apodizations(i,:), args{:});
                if length(self.focus)>1
                    pnp.id = sprintf('pnp_%d', i);
                    pnp.name = sprintf('PNP (%d/%d)', i, length(self.focus));
                else
                    pnp.id = "pnp";
                    pnp.name = "PNP";
                end
                output.pnp(i) = pnp;
                output.intensity(i) = self.calc_intensity(pnp, params);
            end
            analysis_args = fus.util.struct2args(options.analysis_options);
            output.analysis = self.analyze(output, analysis_args{:});
            if options.progressbar
                p.close();
            end
        end
        
        function scenes = to_scenes(self, output, scene, options)
            arguments
                self (1,1) fus.treatment.Solution
                output (1,1) struct
                scene (1,1) fus.Scene
                options.cmaps (1,:) fus.ColorMapper = fus.ColorMapper.empty
                options.clim_pct (1,2) double {mustBeInRange(options.clim_pct,0,1)} = [0, 1]
                options.alim_pct (1,2) double {mustBeInRange(options.alim_pct,0,1)} = [0.1, 0.4]
                options.alim_out (1,2) double {mustBeInRange(options.alim_out,0,1)} = [0, 0.6]
                options.adjust_cmaps (1,1) logical = true
                options.ids (1,:) string {mustBeMember(options.ids, ["pnp", "ita"])} = ["pnp", "ita"]
            end
            if ismember("mri", [scene.volumes.id])
                include_volume = true;
                base_volume = scene.volumes.by_id("mri");
            else
                include_volume = false;
                base_volume = scene.volumes(1);
            end
            volumes = [output.pnp.max().rescale_data("MPa"), self.get_ita(output)];
            ids = ["pnp", "ita"];
            names = ["PNP", "Intensity"];
            default_cmaps = struct('pnp', parula(256), 'ita', turbo(256));
            ii = 0;
            match = find(ismember(ids, options.ids));
            for i = match
                id = ids(i);
                name = names(i);
                volume = volumes(i);
                vmax = volume.percentile(1);
                if ismember(id, string([options.cmaps.id]))
                    cmap = options.cmaps.by_id(id);
                    if vmax*options.clim_pct(2)>cmap.clim_in(2) && options.adjust_cmaps
                        cmap.clim_in = options.clim_pct*vmax;
                        cmap.alim_in = options.alim_pct*vmax;
                    end
                else
                    cmap = fus.ColorMapper(...
                        "id", id, ...
                        cmap=default_cmaps.(id), ...
                        clim_in=options.clim_pct*vmax, ...
                        alim_in=options.alim_pct*vmax, ...
                        alim_out=options.alim_out);
                end
                new_scene = scene.copy();
                new_scene.id = id;
                new_scene.name = sprintf("%s Overlay", name);
                volume.rescale(base_volume.get_units);
                volume.id = id;
                volume.name = name;
                if ~isequal(base_volume.matrix, volume.matrix) || ~isequal(base_volume.coords, volume.coords)
                    volume = volume.transform(base_volume.coords, base_volume.matrix);
                else
                    volume.coords = base_volume.coords;
                end
                if include_volume
                    new_scene.volumes = [base_volume, volume];
                    new_scene.colormaps = [scene.colormaps(1), cmap];
                else
                    new_scene.volumes = volume;
                    new_scene.colormaps = cmap;
                end
                ii = ii+1;
                scenes(ii) = new_scene;
            end
        end

    end
    
    methods (Static)
        function self = from_struct(s)
            arguments
                s struct
            end
            if numel(s) > 1
                self = arrayfun(@fus.treatment.Solution.from_struct, s);
                return
            end
            s.transducer = fus.xdc.Transducer.from_struct(s.transducer);
            s.pulse = fus.Pulse.from_struct(s.pulse);
            s.sequence = fus.Sequence.from_struct(s.sequence);
            s.focus = fus.Point.from_struct(s.focus);
            if isvector(s.delays)
                s.delays = reshape(s.delays, 1, []);
            end
            if isvector(s.apodizations)
                s.apodizations = reshape(s.apodizations, 1, []);
            end
            args = fus.util.struct2args(s);
            self = fus.treatment.Solution(args{:});
        end
        
        function I = calc_intensity(pnp, params, options)
            arguments
                pnp (1,:) fus.Volume
                params (1,:) fus.Volume
                options.units (1,1) string = "W/cm^2"
            end
            sound_speed = params.by_id("sound_speed").rescale_data("m/s");
            density = params.by_id("density").rescale_data("kg/m^3");    
            for i = 1:length(pnp)
                pnp_Pa = pnp(i).rescale_data("Pa");
                I_Wcm2 = (pnp_Pa.data.^2) ./ (2*sound_speed.data .* density.data) * 1e-4;
                I = pnp_Pa;
                if length(pnp)>1
                    I.id = sprintf("intensity_%d", i);
                    I.name = sprintf("Intensity (%d/%d)", i, length(pnp));
                else
                    I.id = "intensity";
                    I.name = "Intensity";
                end
                I.data = I_Wcm2;
                I.units = "W/cm^2";
                I.rescale_data(options.units);
            end
        end
        

    end
end