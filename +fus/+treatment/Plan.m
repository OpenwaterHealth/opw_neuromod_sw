classdef Plan < fus.DataClass
    % TREATMENTPLAN Contains the specification for planning focused ultrasound treatments
    properties
        id (1,1) string {mustBeValidVariableName} = "plan" % Plan ID
        name (1,1) string = "" % Name
        description (1,1) string = "" % Description
        pulse (1,1) fus.Pulse %fus.Pulse parameters
        sequence (1,1) fus.Sequence % Sequencing Plan
        focal_pattern (1,1) fus.bf.FocalPattern % Focal Pattern
        delay_method (1,1) fus.bf.DelayMethod = fus.bf.delaymethods.Direct() % Delay computation method
        apod_method (1,1) fus.bf.ApodMethod = fus.bf.apodmethods.Uniform() % Apodization method
        seg_method (1,1) fus.seg.SegMethod = fus.seg.segmethods.Water() % Segmentation method
        materials (1,:) fus.seg.MaterialReference = fus.seg.MaterialReference.load_default("all") % Material references
        sim_setup (1,1) fus.sim.Setup % Simulation Grid
        param_constraints (1,:) fus.treatment.ParameterConstraint % Constraints on Output Parameters
        target_constraints(1,:) fus.treatment.TargetConstraint % Constraints on Targets
        analysis_options (1,1) struct = struct(); % Options for solution.analyze
    end
    
    methods
        function self = Plan(options)
            %TREATMENTPLAN Construct a TreatmentPlan
            % plan = fus.treatment.Plan("param", value, ...)
            % A Treatment Plan is a specification for a focused ultrasound treatment. It is used
            % to generate a Treatment Solution for a particular transducer/volume/target. The plan
            % describes the pulse and sequencing specifications for the treatment, the sptial patterning of
            % treatment foci around the nominal target and requested pressure, the specification for how delays
            % and apodizations are to be calculated for each focus, the simulation configuration, and constraints
            % on both the estimated acoustic properties and the positions of the target relative to the transducer.
            %
            % Optional Parameters:
            %   'id' (string): Plan ID. Default: "plan"
            %   'name' (string): Plan Name. Default: ""
            %   'description' (string): Plan Description. Default: ""
            %   'pulse' (fus.Pulse): Pulse Parameters. Default: fus.Pulse()
            %   'sequence' (fus.Sequence): Sequence Parameters. Default: fus.Sequence()
            %   'focal_pattern' (fus.bf.FocalPattern): Focal Pattern. Default: fus.bf.FocalPattern()
            %   'delay_method' (fus.bf.DelayMethod) - Delay computation method
            %   'apod_method' (fus.bf.ApodMethod) - Apodization method  
            %   'seg_method' (fus.seg.SegMethod) - Segmentation method
            %   'materials' (fus.seg.MaterialReference) - Material references
            %   'sim_setup' (fus.sim.Setup): Simulation Grid. Default: fus.sim.Setup()
            %   'param_constraints' (fus.treatment.ParameterConstraint): Constraints on Output Parameters. Default: fus.treatment.ParameterConstraint()
            %   'target_constraints' (fus.treatment.TargetConstraint): Constraints on Targets. Default: fus.treatment.TargetConstraint()
            %   'analysis_options' (struct): Options for solution.analyze. Default: struct()
            %
            % Returns:
            %   plan (fus.treatment.Plan): Treatment Plan
            arguments
                options.?fus.treatment.Plan
            end
            self.parse_props(options)
        end
        
        function plan = by_id(self, id)
            arguments
                self (1,:) fus.treatment.Plan
                id (1,:) string {fus.util.mustBeID(id, self)}
            end
            plan = arrayfun(@(id)self(strcmp(id, [self.id])), id);
        end

        function varargout  = calc_solution(self, scene, options)
            %CALC_SOLUTION Calculate a Treatment Solution
            % [solution, output] = plan.calc_solution(scene)
            % [solution, output] = plan.calc_solution(scene, "param", value, ...)
            % solution = plan.calc_solution(scene, "simulate", false)
            %
            % CALC_SOLUTION is a multi-part method that computes the delays and 
            % apodizations for each focus in the treatment plan, simulates the
            % resulting pressure field to adjust transmit pressures to reach target
            % pressures, and then analyzes the resulting pressure field to compute
            % the resulting acoustic parameters.
            %
            % Inputs:
            %   scene (fus.Scene): fus.Scene
            %
            % Optional Parameters:
            %   'target_id' (string): Target ID. Default: scene.targets.all_ids
            %   'simulate' (logical): Simulate the solution. Default: true
            %   'scale_solution' (logical): Scale the solution to the requested pressure. Default: true
            %   'sim_options' (struct): Options for fus.sim.Setup.simulate. Default: plan.sim_setup.options
            %   'analysis_options' (struct): Options for solution.analyze. Default: plan.analysis_options
            %   'on_pulse_mismatch' (string): Action to take if the number of pulses in the sequence does not match the number of foci. Default: "error"
            %   'progressbar' (logical): Show progress bar. Default: true
            %   'figure' (int): Figure number for progress bar. Default: -1
            %   'log' (fus.util.Logger): Logger. Default: fus.util.Logger.get()
            %
            % Returns:
            %   solution (Solution): Treatment Solution

            arguments
                self fus.treatment.Plan
                scene fus.Scene
                options.target_id (1,:) string {mustBeValidVariableName} = scene.targets.all_ids
                options.simulate (1,1) logical = true
                options.scale_solution (1,1) logical = true
                options.sim_options (1,1) struct = struct()
                options.analysis_options (1,1) struct = self.analysis_options
                options.on_pulse_mismatch (1,1) string {mustBeMember(options.on_pulse_mismatch, ["error", "round", "roundup", "rounddown"])} = "error"
                options.progressbar (1,1) logical = true
                options.figure = -1
                options.log fus.util.Logger = fus.util.Logger.get()
            end
            log = options.log;
            target = scene.targets.by_id(options.target_id);
            foci = self.focal_pattern.get_targets(target);
            target_check = self.check_targets(target);
            if ~all([target_check.ok])
                msg = sprintf('%d foci are out of bounds', sum(~[target_check.ok]));
                log.error(msg);
                for i = find(~[target_check.ok])
                    log.error("%s: %s", foci(i).name, target_check(i).message);
                end
                log.throw_error("Cannot plan for target %s", target.name);
            end
            if options.progressbar
                p = fus.util.ProgressBar("title", "Planning Treatment...", "figure", options.figure, "tag", "sim_plan");
            else
                p = -1;
            end            
            solution_sequence = self.sequence.copy();
            if mod(self.sequence.pulse_count, length(foci)) ~= 0
                switch options.on_pulse_mismatch
                    case "error"
                        log.throw_error("Pulse Count (%d) is not a multiple of the number of foci (%d)", self.sequence.pulse_count, length(foci));
                    case "round"
                        solution_sequence.pulse_count = round(self.sequence.pulse_count/length(foci))*length(foci);
                        log.warning("Pulse Count (%d) is not a multiple of the number of foci (%d). Rounding to %d", self.sequence.pulse_count, length(foci), solution_sequence.pulse_count);
                    case "roundup"
                        solution_sequence.pulse_count = ceil(self.sequence.pulse_count/length(foci))*length(foci);
                        log.warning("Pulse Count (%d) is not a multiple of the number of foci (%d). Rounding to %d", self.sequence.pulse_count, length(foci),  solution_sequence.pulse_count);
                    case "rounddown"
                        solution_sequence.pulse_count = floor(self.sequence.pulse_count/length(foci))*length(foci);
                        log.warning("Pulse Count (%d) is not a multiple of the number of foci (%d). Rounding to %d", self.sequence.pulse_count, length(foci),  solution_sequence.pulse_count);
                end
            end         
            solution = fus.treatment.Solution(...
                plan_id=self.id, ...
                target_id=target.id, ...
                description=self.description, ...
                transducer=scene.transducer, ...
                delays=zeros(length(foci), scene.transducer.numelements), ...
                apodizations=zeros(length(foci), scene.transducer.numelements), ...
                pulse=self.pulse.copy(), ...
                sequence=solution_sequence, ...
                focus=foci);
            for i = 1:length(foci)
                focus = foci(i);
                log.info('Beamforming focus %d/%d...', i, length(foci));
                if options.progressbar;p.update(i/length(foci), sprintf('Beamforming focus %d/%d...', i, length(foci)));end
                [delays, apod] = self.beamform(scene.transducer, focus, scene.volumes);
                solution.delays(i,:) = delays;
                solution.apodizations(i,:) = apod;
            end
            if options.progressbar;p.close();end

            if options.simulate
                if nargout < 2
                    log.warning("Simulation was requested, but no output is assigned. Use [solution, output] = plan.simulate(... to capture simulation output");
                end
                sim_options = struct(...
                    "dt", self.sim_setup.dt, ...
                    "t_end", self.sim_setup.t_end);
                sim_options = fus.util.merge_struct(sim_options, self.sim_setup.options, "add");
                sim_options = fus.util.merge_struct(sim_options, options.sim_options, "add");
                output = solution.simulate(scene.volumes, ...
                    "sim_options", sim_options, ...
                    "analysis_options", options.analysis_options, ...
                    "progressbar", options.progressbar, ...
                    "parent", options.figure);
                if options.scale_solution
                    [solution, output] = scale_solution(self, solution, output);
                end
            elseif nargout > 1
               log.warning("Simulation was not requested, but simulation output was assigned to an output. Result is blank.")
               output = [];
            end
            if nargout>0
                varargout{1} = solution;
            end
            if nargout>1
                varargout{2} = output;
            end
            solution.created_on = datetime;
        end
        
        function result = check_targets(self, target)
            % CHECK_TARGETS Check if target is within bounds
            % result = plan.check_targets(self, target)
            %
            % Inputs:
            %   target (1,:) fus.Point: Target to check
            %
            % Returns:
            %   result (1,:) struct: Result of check. Fields:
            %       id (1,1) string: Target ID
            %       ok (1,1) logical: True if target is within bounds
            %       message (1,1) string: Error message if target is out of bounds
            %       <dim> (1,1) string: Status of <dim> dimension
            arguments
                self fus.treatment.Plan
                target (1,:) fus.Point
            end
            if numel(target) > 1
                result = arrayfun(@self.check_targets, target);
                return;
            end
            result.id = target.id;
            result.ok = true;
            result.message = "";
            for i = 1:length(self.target_constraints)
                c = self.target_constraints(i);
                dim = c.dim;
                status = c.get_status(target.get_position(dim, "units", c.units));
                status.id = target.id;
                status.dim = dim;
                result.(dim) = status.state;
                if ~status.ok && isequal(result.message,"")
                    result.message = status.message;
                end
                if ~status.ok
                    result.ok = false;
                end
            end 
        end
        
        function result = check_analysis(self, analysis)
            % CHECK_ANALYSIS Check if analysis is within bounds
            % result = plan.check_analysis(self, analysis)
            %
            % Inputs:
            %   analysis (1,:) struct: Analysis to check
            %
            % Returns:
            %   result (1,:) struct: Result of check. Fields:
            for i = 1:length(self.param_constraints)
                pc = self.param_constraints(i);
                status = pc.get_status(analysis.(pc.id));
                result(i) = struct(...
                    "id", pc.id, ...
                    "status", status, ...
                    "ok", status=="ok", ...
                    "message", pc.get_message(analysis.(pc.id)));
            end
        end
        
        function tab = get_table(self)
            % GET_TABLE Get table of plan parameters
            % tab = plan.get_table(self)
            %
            % Returns:
            %   tab (1,:) table: Table of plan parameters
            pulse_tab = self.pulse.get_table();
            pulse_tab.Category = repmat("Pulse",size(pulse_tab,1),1);
            pulse_tab = pulse_tab(:, [4, 1, 2, 3]);
            seq_tab = self.sequence.get_table();
            seq_tab.Category = repmat("Sequence",size(seq_tab,1),1);
            seq_tab = seq_tab(:, [4, 1, 2, 3]);
            foc_tab = self.focal_pattern.get_table();
            foc_tab.Category = repmat("Focus",size(foc_tab,1),1);
            foc_tab = foc_tab(:, [4, 1, 2, 3]);
            bf_tab = struct2table([...
                table2struct(self.delay_method.get_table)',...
                table2struct(self.apod_method.get_table)',...
                table2struct(self.seg_method.get_table)']);
            bf_tab.Category = repmat("Beamforming",size(bf_tab,1),1);
            bf_tab = bf_tab(:, [4, 1, 2, 3]);
            tab = [pulse_tab;seq_tab;foc_tab;bf_tab];            
        end
        
        function varargout = scale_solution(self, solution, output, options)
            % SCALE_SOLUTION Scale solution to match target pressure
            % scaled_solution = plan.scale_solution(self, solution)
            % plan.scale_solution(self, solution, output)
            % plan.scale_solution(self, solution, output, "param", value, ...)
            % 
            % SCALE_SOLUTION scales the solution to match the target pressure.
            % If no output is requested, the solution is scaled in-place.
            % 
            % Inputs:
            %   solution (1,:) fus.treatment.Solution: Solution to scale
            %   output (1,1) struct: simulation output
            %
            % Optional Parameters:
            %   'analysis_options' (struct): Overwrite analysis options. Default: self.analysis_options
            %
            % Returns:
            %   scaled_solution (1,:) fus.treatment.Solution: Scaled solution
            %   scaled_output (1,:) struct: Scaled output            
            arguments
                self fus.treatment.Plan
                solution (1,:) fus.treatment.Solution
                output (1,1) struct 
                options.analysis_options (1,1) struct = self.analysis_options;
            end
            if nargout > 1
                scaled_solution = solution.copy();
                varargout{1} = scaled_solution;
            else
                scaled_solution = solution;
            end
            analysis_args = fus.util.struct2args(options.analysis_options);
            analysis = scaled_solution.analyze(output, analysis_args{:});
            scaling_factor = (self.focal_pattern.target_pressure/1e6) ./ analysis.mainlobe_pnp_MPa;
            max_scaling = max(scaling_factor);
            v0 = self.pulse.amplitude;
            v1 = v0 * max_scaling;
            apod_factors = scaling_factor / max_scaling;
            scaled_output = struct(...
                "pnp", output.pnp.copy(), ...
                "intensity", output.intensity.copy(), ...
                "analysis", output.analysis);
            for i = 1:length(output.pnp)
                scaling = v1/v0*apod_factors(i);
                scaled_output.pnp(i).data = output.pnp(i).data*scaling;
                scaled_output.intensity(i).data = output.intensity(i).data*scaling^2;
                scaled_solution.apodizations(i,:) = solution.apodizations(i,:)*apod_factors(i);
            end
            scaled_solution.pulse.amplitude = v1;
            scaled_output.analysis = scaled_solution.analyze(scaled_output, analysis_args{:});
            if nargout > 1
                varargout{2} = scaled_output;
            end
        end
        
        function s = to_struct(self)
            % TO_STRUCT Convert plan to struct
            % s = plan.to_struct(self)
            %
            % Returns:
            %   s (1,1) struct: Plan as struct
            s = to_struct@fus.DataClass(self);
            for f = ["param_constraints", "target_constraints"]
                if isempty(self.(f))
                    s.(f) = struct();
                end
            end
        end
        
        function sim_scene = transform_sim_scene(self, scene, options)
            % TRANSFORM_SIM_SCENE Transform scene for simulation
            % sim_scene = plan.transform_sim_scene(self, scene)
            % sim_scene = plan.transform_sim_scene(self, scene, "param", value, ...)
            %
            % TRANSFORM_SIM_SCENE transforms the scene for simulation. This
            % includes transforming the scene to the simulation grid and
            % segmenting and the acoustic parameters to the scene. If a standoff mask
            % is provided, the standoff region will be assigned to the standoff properties
            %
            % Inputs:
            %   scene (fus.Scene): Base scene to transform
            %
            % Optional Parameters:
            %   'units' (string). Units of simulation grid. Default: "m"
            %   'id' (string). ID of simulation grid. Default: "sim"
            %   'name' (string). Name of simulation grid. Default: "Simulation Grid"
            %   'standoff_mask' (logical). Mask of standoff region. Default: []
            %
            % Returns:
            %   sim_scene (fus.Scene): Transformed scene
            arguments 
                self fus.treatment.Plan
                scene fus.Scene
                options.units (1,1) string {fus.util.mustBeDistance} = "m"
                options.id (1,1) string {mustBeValidVariableName} = "sim"
                options.name (1,1) string = "Simulation Grid"
                options.standoff_mask logical = []
            end
            sim_scene = self.sim_setup.transform_scene(...
                scene, ...
                units=options.units, ...
                id=options.id, ...
                name=options.name); 
            params = self.seg_method.segment_params(sim_scene.volumes, self.materials, "standoff_mask", options.standoff_mask);
            sim_scene.volumes = [sim_scene.volumes params];
        end
        
        function sim_scene = gen_reference_sim_scene(self, trans, targets, options)
            % GEN_REFERENCE_SIM_SCENE Generate reference simulation scene
            % sim_scene = plan.gen_reference_sim_scene(self, trans, targets)
            % sim_scene = plan.gen_reference_sim_scene(self, trans, targets, "param", value, ...)
            %
            % GEN_REFERENCE_SIM_SCENE transforms a scene for simulation in the absence of data
            % includes transforming the scene to the simulation grid and
            % segmenting and the acoustic parameters to the scene. If a standoff mask
            % is provided, the standoff region will be assigned to the standoff properties
            %
            % Inputs:
            %   trans fus.xdc.Transducer: transducer
            %   targets (1,:) fus.Point: Targets
            %
            % Optional Parameters:
            %   'material_id' (string). Material ID for reference params.
            %     Default: "water"
            %   'units' (string). Units of simulation grid. Default: "m"
            %   'id' (string). ID of simulation grid. Default: "sim"
            %   'name' (string). Name of simulation grid. Default: "Simulation Grid"
            %   'standoff_mask' (logical). Mask of standoff region. Default: []
            %
            % Returns:
            %   sim_scene (fus.Scene): Transformed scene            
            arguments
                self fus.treatment.Plan
                trans fus.xdc.Transducer
                targets (1,:) fus.Point
                options.material_id (1,1) string {mustBeValidVariableName} = "water"
                options.units (1,1) string {fus.util.mustBeDistance} = "m"
                options.id (1,1) string {mustBeValidVariableName} = "sim"
                options.name (1,1) string = "Simulation Grid"
                options.standoff_mask logical = []
            end
            coords = self.sim_setup.get_coords("units", options.units);
            matrix = trans.get_matrix("units", options.units);
            sim_targets = targets.transform(matrix, "dims", [coords.id], "units", coords.get_units);
            sim_trans = trans.transform(matrix, "units", coords.get_units);
            
            seg_index = self.materials.get_index_map();
            if ~isfield(seg_index, options.material_id)
                error("No material '%s' found in index", options.material_id);
            end
            ref_index = seg_index.(options.material_id);
            ref_seg = fus.Volume(...
                ref_index*ones(coords.length), ...
                coords, ...
                "attrs", struct("ref_material", self.materials(ref_index)));
            params = fus.seg.map_params(ref_seg, self.materials);
            sim_scene = fus.Scene(...
                "id", options.id, ...
                "name", options.name, ...
                "targets", sim_targets, ...
                "volumes", params, ...
                "colormaps", fus.ColorMapper("cmap", bone(256)), ...
                "transducer", sim_trans); 
        end        
    
        function [delays, apod] = beamform(self, trans, focus, params)
            % BEAMFORM Compute Delays and Apodizations
            %  [delays, apod] = plan.beamform(trans, focus, params)
            %
            % Inputs:
            %   trans (fus.xdc.Transducer) - Transducer to beamform with
            %   focus (fus.Point) - Point to focus on
            %   params (1,:) fus.Volume - Material property maps
            %
            % Returns:
            %   delays (1,:) double - Delay values
            %   apod (1,:) double - Apodization values
            arguments
                self fus.treatment.Plan
                trans fus.xdc.Transducer
                focus fus.Point
                params (1,:) fus.Volume
            end
            delays = self.delay_method.calc_delays(trans, focus, params);
            apod = self.apod_method.calc_apod(trans, focus.position, params);            
        end
    end

    methods (Static)
        function plan = from_struct(s)
            % FROM_STRUCT Create a TreatmentPlan from a struct
            % plan = fus.treatment.Plan.from_struct(s)
            %
            % Inputs:
            %   s (struct): Struct with fields matching the TreatmentPlan constructor
            %
            % Returns:
            %   plan (fus.treatment.Plan): TreatmentPlan object
            if numel(s) > 1
                plan = arrayfun(@fus.treatment.Plan.from_struct, s);
                return
            end
            s.sim_setup = fus.sim.Setup.from_struct(s.sim_setup);
            s.focal_pattern = fus.bf.FocalPattern.from_struct(s.focal_pattern);
            s.pulse = fus.Pulse.from_struct(s.pulse);
            s.delay_method = fus.bf.DelayMethod.from_struct(s.delay_method);
            s.apod_method = fus.bf.ApodMethod.from_struct(s.apod_method);
            s.seg_method = fus.seg.SegMethod.from_struct(s.seg_method);
            if isfield(s, 'materials')
                s.materials = fus.seg.MaterialReference.from_struct(s.materials);
            end
            s.sequence = fus.Sequence.from_struct(s.sequence);
            if isfield(s, "param_constraints")
                s.param_constraints = fus.treatment.ParameterConstraint.from_struct(s.param_constraints);
            end
            if isfield(s, "target_constraints")
                s.target_constraints = fus.treatment.TargetConstraint.from_struct(s.target_constraints);
            end
            args = fus.util.struct2args(s);
            plan = fus.treatment.Plan(args{:});
        end
        
        function plan = from_file(filename)
            % FROM_FILE Load a TreatmentPlan from a file
            % plan = fus.treatment.Plan.from_file(filename)
            %
            % Inputs:
            %   filename (string): Path to file
            %
            % Returns:
            %   plan (fus.treatment.Plan): TreatmentPlan object
            arguments
                filename (1,1) string {mustBeFile}
            end
            s = jsondecode(fileread(filename));
            if isfield(s, "target_constraints") && isfield(s.target_constraints, "id")
                warning("Updating plan")
                for i = 1:length(s.target_constraints)
                    s.target_constraints(i).dim = s.target_constraints(i).id;
                end
                s.target_constraints = orderfields(rmfield(s.target_constraints, 'id'), ["dim", "name", "units", "fstr", "min", "max"]);
                fus.util.struct2json(s, filename);
            end
            if isfield(s, 'sim_options')
                warning("Updating plan")
                s.sim_setup.options = s.sim_options;
                s = rmfield(s, "sim_options");
                fus.util.struct2json(s, filename);
            end
            if isfield(s, 'sim_grid')
                warning("Updating plan")
                s.sim_setup = s.sim_grid;
                s = rmfield(s, "sim_grid");
                fus.util.struct2json(s, filename);
            end
            plan = fus.treatment.Plan.from_struct(s);
        end
    end
end