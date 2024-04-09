classdef Database < fus.DataClass
    % DATABASE Class for interfacing with open-LIFU file storage
    properties
        path (1,1) string {mustBeFolder} = "." % Root location of database
        log fus.util.Logger = fus.util.Logger.get() % Logging utility
    end
    
    methods
        function self = Database(options)
            % DATABASE Create database object
            % db = DATABASE()
            % db = DATABASE("path", path_to_db)
            % db = DATABASE("path", path_to_db, "log", log_object)
            %
            % DATABASE creates a new pointer to the location of the database on disk. 
            % The created object will then have the ability to query, read,
            % and write from the objects stored in the database
            arguments
                options.log fus.util.Logger = fus.util.Logger.get() % Logging utility
                options.path (1,1) string {mustBeFolder} = fus.Database.get_default_path % Root location of database
            end
            self.parse_props(options);
        end
        
        function plan_added = add_plan(self, treatment_plan, options)
            % ADD_PLAN Add a treatment plan to the database
            %
            % This function adds a treatment plan object to the database.
            % The option on_conflict specifies how to handle the case when
            % the treatment plan ID already exists in the database. The function returns
            % 1 if the treatment plan was successfully added to the
            % database, or 0 otherwise.
            %
            % Usage:
            %
            %   plan_added = add_plan(self, treatment_plan)
            %   plan_added = add_plan(self, treatment_plan, options)
            %
            % Input:
            %
            %   self: A database object.
            %   treatment_plan: A treatment plan object.
            %
            % Optional Parameters:   
            %     - on_conflict: A string specifying how to handle conflicts. Possible
            %       values are "overwrite", "error", or "skip". Default is "error".
            %
            % Output:
            %
            %   plan_added: A logical value indicating whether the treatment plan was added
            %   to the database (1) or not (0).
            arguments
                self fus.Database
                treatment_plan fus.treatment.Plan
                options.on_conflict (1,1) string {mustBeMember(options.on_conflict, ["overwrite", "error", "skip"])} = "error"
            end
            self.log.info('Adding Plan %s to Database...', treatment_plan.id)
            plan_ids = self.get_plan_ids();
            if ismember(treatment_plan.id, plan_ids)
                switch options.on_conflict
                    case "error"
                        self.log.throw_error("add_plan:PlanExists", "Plan %s is already in the database", treatment_plan.id);
                    case "skip"
                        self.log.warning("Plan %s is already in the database. Skipping.", treatment_plan.id);
                        plan_added = 0;
                        return
                    case "overwrite"
                       self.log.warning("Plan %s is already in the database. Overwriting.", treatment_plan.id);
                    otherwise
                        self.log.throw_error("add_plan:InValidConflictOption", "Invalid conflict option '%s'", options.on_conflict);
                end
            end
            plan_filename = self.get_plan_filename(treatment_plan.id);
            treatment_plan.to_file(plan_filename);
            plan_ids(end+1) = treatment_plan.id;
            plan_ids = sort(unique(plan_ids));
            self.write_plan_ids(plan_ids);
            plan_added = 1;
            self.log.info("Added Plan %s to Database", treatment_plan.id);
        end
        
        function session_added = add_session(self, subject, session, options)
            % ADD_SESSION Add Session to Database
            %
            %   session_added = add_session(self, subject, session) adds a session to
            %   the database associated with a subject. By default, if the session
            %   already exists, it will raise an error.
            %
            %   session_added = add_session(self, subject, session, 'Param1', Value1, ...)
            %   allows you to specify optional parameters as Param, Value pairs to
            %   control the behavior when the session already exists.
            %
            %   Input: 
            %   self (fus.Database): The Database object.
            %   subject (fus.Subject): The subject to which the session belongs. 
            %   session (fus.Session): The session to add.
            %   
            %   Optional Parameters:
            %       'on_conflict' (string): Specifies the action to take
            %           when the session already exists. Possible values
            %           are 'overwrite' (default), 'error', or 'skip'.
            %
            %   Returns: 
            %       session_added (logical): True if the session was
            %           added successfully, false if it was skipped or
            %           overwritten due to conflicts.
            arguments
                self fus.Database
                subject fus.Subject
                session fus.Session
                options.on_conflict (1,1) string {mustBeMember(options.on_conflict, ["overwrite", "error", "skip"])} = "error"
            end
            self.log.info('Adding Session %s to Subject %s...', session.id, subject.id);
            session_ids = self.get_session_ids(subject.id);
            if ismember(session.id, session_ids)
                switch options.on_conflict
                    case "error"
                        self.log.throw_error("add_to_dom:SessionExists", "Session %s is already attached to Subject", session.id);
                    case "skip"
                        self.log.warning("Session %s is already attached to Subject. Skipping.", session.id);
                        session_added = false;
                        return
                    case "overwrite"
                        self.log.warning("Session %s is already attached to Subject. Overwriting.", session.id);
                    otherwise
                        self.log.throw_error("add_to_dom:InValidConflictOption", "Invalid conflict option '%s'", options.on_conflict);
                end
            end
            session_ids(end+1) = session.id;
            session_ids = sort(unique(session_ids));
            self.write_session_ids(subject.id, session_ids);
            session_filename = self.get_session_filename(subject.id, session.id);
            session.subject_id = subject.id;
            session.to_file(session_filename);
            transducer_ids = self.get_transducer_ids();
            if ~isempty(session.transducer) && ~ismember(session.transducer.id, transducer_ids)
                self.log.info('Adding transducer %s to database...', session.transducer.id);
                self.add_transducer(session.transducer);
            end
            if ~ismember(session.volume.id, subject.volumes)
                self.log.warning('Volume %s is not attached to Subject %s', session.volume.id, subject.id);
                self.add_volume(subject, session.volume, "on_conflict", "overwrite");
            end
            self.log.info('Added Session %s to Subject %s', session.id, subject.id);
            session_added = true;
        end
        
        function subject_added = add_subject(self, subject, options)
            % ADD_SUBJECT Add subject to Database.
            %
            % subject_added = add_subject(self, subject, 'Param1', Value1, ...) adds a
            % subject to the database. By default, if the subject already exists, it
            % will raise an error.
            %
            % Input:
            %   self (fus.Database): The Database object.
            %   subject (fus.Subject): The subject to add.
            %
            % Optional Parameters:
            %   'on_conflict' (string): Specifies the action to take when the subject
            %       already exists. Possible values are 'overwrite' (default), 'error',
            %       or 'skip'.
            %
            % Returns:
            %   subject_added (logical): 1 if the subject was added successfully, 0 if
            %       it was skipped or overwritten due to conflicts.
            arguments
                self fus.Database
                subject fus.Subject
                options.on_conflict (1,1) string {mustBeMember(options.on_conflict, ["overwrite", "error", "skip"])} = "error"
            end
            self.log.info('Adding Subject %s to Database...', subject.id)
            subject_ids = self.get_subject_ids();
            if ismember(subject.id, subject_ids)
                switch options.on_conflict
                    case "error"
                        self.log.throw_error("add_subject:SubjectExists", "Subject %s is already in the database", subject.id);
                    case "skip"
                        self.log.warning("Subject %s is already in the database. Skipping.", subject.id);
                        subject_added = 0;
                        return
                    case "overwrite"
                       self.log.warning("Subject %s is already in the database. Overwriting.", subject.id);
                    otherwise
                        self.log.throw_error("add_subject:InValidConflictOption", "Invalid conflict option '%s'", options.on_conflict);
                end
            end
            subject_filename = self.get_subject_filename(subject.id);
            subject.to_file(subject_filename);
            subject_ids(end+1) = subject.id;
            subject_ids = sort(unique(subject_ids));
            self.write_subject_ids(subject_ids);
            subject_added = 1;
            self.log.info("Added Subject %s to Database", subject.id);
        end
        
        function trans_added = add_transducer(self, trans, options)
            % ADD_TRANSDUCER Add transducer to Database.
            %
            % trans_added = add_transducer(self, trans, 'Param1', Value1, ...) adds a
            % transducer to the database. By default, if the transducer already exists,
            % it will raise an error.
            %
            % Input:
            %   self (fus.Database): The Database object.
            %   trans (fus.xdc.Transducer): The transducer to add.
            %
            % Optional Parameters:
            %   'save_matrix' (logical): Specifies whether to save the transducer
            %       matrix. Default is false.
            %   'on_conflict' (string): Specifies the action to take when the transducer
            %       already exists. Possible values are 'overwrite' (default), 'error',
            %       or 'skip'.
            %
            % Returns:
            %   trans_added (logical): 1 if the transducer was added successfully, 0 if
            %       it was skipped or overwritten due to conflicts.
            arguments
                self fus.Database
                trans fus.xdc.Transducer
                options.save_matrix (1,1) logical = false
                options.on_conflict (1,1) string {mustBeMember(options.on_conflict, ["overwrite", "error", "skip"])} = "error"
            end
            transducer_ids = self.get_transducer_ids();
            if ismember(trans.id, transducer_ids)
                switch options.on_conflict
                    case "error"
                        self.log.throw_error("add_transducer:TransducerExists", "Transducer %s is already in the database", trans.id);
                    case "skip"
                        self.log.warning("Transducer %s is already in the database. Skipping.", trans.id);
                        trans_added = 0;
                        return
                    case "overwrite"
                        self.log.warning("Transducer %s is already in the database. Overwriting.", trans.id);
                    otherwise
                        self.log.throw_error("add_transducer:InValidConflictOption", "Invalid conflict option '%s'", options.on_conflict);
                end
            end
            transducer_filename = self.get_transducer_filename(trans.id);
            if ~options.save_matrix
                trans = trans.copy();
                trans.matrix = eye(4);
            end
            trans.to_file(transducer_filename);
            transducer_ids(end+1) = trans.id;
            transducer_ids = sort(unique(transducer_ids));
            self.write_transducer_ids(transducer_ids)
            self.log.info('Added transducer %s', trans.id);
            trans_added = 1;
        end
        
        function solution_added = add_solution(self, solution, subject_id, session_id, options)
            % ADD_SOLUTION Add a treatment solution to the database.
            %
            % solution_added = add_solution(self, solution, subject_id, session_id, 'Param1', Value1, ...)
            % adds a treatment solution to the database associated with a subject's
            % session. By default, if the solution already exists, it will raise an error.
            %
            % Inputs:
            %   self (fus.Database): The Database object.
            %   solution (fus.treatment.Solution): The treatment solution to add.
            %   subject_id (string): The subject's ID.
            %   session_id (string): The session's ID.
            %
            % Optional Parameters:
            %   'on_conflict' (string): Specifies the action to take when the solution
            %       already exists. Possible values are 'overwrite' (default), 'error',
            %       or 'skip'.
            %
            % Returns:
            %   solution_added (logical): True if the solution was added successfully,
            %       false if it was skipped or overwritten due to conflicts.
            arguments
                self fus.Database
                solution fus.treatment.Solution
                subject_id (1,1) string {mustBeValidVariableName}
                session_id (1,1) string {mustBeValidVariableName}
                options.output struct = struct.empty
                options.on_conflict (1,1) string {mustBeMember(options.on_conflict, ["overwrite", "error", "skip"])} = "error"
            end
            plan_id = string(solution.plan_id);
            target_id = string(solution.target_id);
            solutions_filename = get_solutions_filename(self, subject_id, session_id);
            ids_by_plan = get_solutions(self, subject_id, session_id);
            if isfield(ids_by_plan, plan_id) && ismember(target_id, ids_by_plan.(plan_id))
                switch options.on_conflict
                        case "error"
                            self.log.throw_error("add_solution:SolutionExists", "Session %s is already attached to Session", plan_id, target_id);
                        case "skip"
                            self.log.warning("Solution %s/%s is already attached to Session. Skipping.", plan_id, target_id);
                            solution_added = 0;
                            return
                        case "overwrite"
                            self.log.warning("Solution %s/%s is already attached to Session. Overwriting.", plan_id, target_id);
                        otherwise
                            self.log.throw_error("add_solution:InValidConflictOption", "Invalid conflict option '%s'", options.on_conflict);
                end
            end
            s = solution.to_struct();
            json_filename = self.get_solution_filename(subject_id, session_id, plan_id, target_id, "json");
            if ~isempty(options.output)
                mat_filename = self.get_solution_filename(subject_id, session_id, plan_id, target_id, "mat");
                dirname = fileparts(mat_filename);
                if (dirname ~= "") && ~isfolder(dirname)
                    mkdir(dirname);
                end
                mat_data = struct(...
                    'pnp', options.output.pnp.to_struct(),...
                    'intensity', options.output.intensity.to_struct());
                save(mat_filename, '-struct', 'mat_data');
                analysis_filename = self.get_solution_filename(subject_id, session_id, plan_id, target_id, "analysis.json");
                fus.util.struct2json(options.output.analysis, analysis_filename);
            end
            s.transducer = struct('id', s.transducer.id);
            fus.util.struct2json(s, json_filename);
            if isfield(ids_by_plan, plan_id)
                if ~ismember(target_id, ids_by_plan.(plan_id))
                    ids_by_plan.(plan_id)(end+1) = target_id;
                end
            else
                ids_by_plan.(plan_id) = target_id;
            end
            fus.util.struct2json(ids_by_plan, solutions_filename);
            self.log.info('Added %s/%s to Session %s.', plan_id, target_id, session_id);
        end

        function standoff_added = add_standoff(self, transducer_id, standoff, options)
            % ADD_STANDOFF Add a standoff to the database.
            %
            % standoff_added = add_standoff(self, transducer_id, standoff, 'Param1', Value1, ...)
            % adds a standoff to the database. By default, if the standoff already
            % exists, it will raise an error.
            %
            % Inputs:
            %   self (fus.Database): The Database object.
            %   transducer_id (string): The transducer's ID.
            %   standoff (Standoff): The standoff to add.
            %
            % Optional Parameters:
            %   'on_conflict' (string): Specifies the action to take when the standoff
            %       already exists. Possible values are 'overwrite' (default), 'error',
            %       or 'skip'.
            %
            % Returns:
            %   standoff_added (logical): True if the standoff was added successfully,
            %       false if it was skipped or overwritten due to conflicts.
            %
            % See Also:
            %   Standoff.to_struct
            arguments
                self fus.Database
                transducer_id (1,1) string {mustBeValidVariableName}
                standoff fus.xdc.Standoff
                options.on_conflict (1,1) string {mustBeMember(options.on_conflict, ["overwrite", "error", "skip"])} = "error"
            end
            standoff_id = string(standoff.id);
            standoff_filename = self.get_standoff_filename(transducer_id, standoff_id);
            if isfile(standoff_filename)
                switch options.on_conflict
                        case "error"
                            self.log.throw_error("add_standoff:StandoffExists", "Standoff %s already exists", standoff_id);
                        case "skip"
                            self.log.warning("Standoff %s already exists. Skipping.", standoff_id);
                            standoff_added = 0;
                            return
                        case "overwrite"
                            self.log.warning("Standoff %s already exists. Overwriting.", standoff_id);
                        otherwise
                            self.log.throw_error("add_standoff:InValidConflictOption", "Invalid conflict option '%s'", options.on_conflict);
                end
            end
            s = standoff.to_struct();
            fus.util.struct2json(s, standoff_filename);
            self.log.info('Added standoff %s to %s.', standoff_id, transducer_id);
            standoff_added = 1;
        end

        function system_added = add_system(self, sys, options)
            % ADD_SYSTEM Add an ultrasound system to the database.
            %
            % system_added = add_system(self, sys, 'Param1', Value1, ...) adds an
            % ultrasound system to the database. By default, if the system already
            % exists, it will raise an error.
            %
            % Inputs:
            %   self (fus.Database): The Database object.
            %   sys (fus.sys.UltrasoundSystem): The ultrasound system to add.
            %
            % Optional Parameters:
            %   'on_conflict' (string): Specifies the action to take when the system
            %       already exists. Possible values are 'overwrite' (default), 'error',
            %       or 'skip'.
            %
            % Returns:
            %   system_added (logical): True if the system was added successfully,
            %       false if it was skipped or overwritten due to conflicts.
             arguments
                self fus.Database
                sys fus.sys.UltrasoundSystem
                options.on_conflict (1,1) string {mustBeMember(options.on_conflict, ["overwrite", "error", "skip"])} = "error"
            end
            systems_filename = self.get_systems_filename();
            sys_ids = self.get_system_ids();
            if ismember(sys.id, sys_ids)
                switch options.on_conflict
                        case "error"
                            self.log.throw_error("add_system:SystemExists", "System %s is already in Database", sys.id);
                        case "skip"
                            self.log.warning("System %s is already in Database. Skipping.", sys.id);
                            system_added = 0;
                            return
                        case "overwrite"
                            self.log.warning("System %s is already in Database. Overwriting.", sys.id);
                        otherwise
                            self.log.throw_error("add_system:InValidConflictOption", "Invalid conflict option '%s'", options.on_conflict);
                end
            else
                sys_index = struct('system_ids', [sys_ids sys.id]);
                fus.util.struct2json(sys_index, systems_filename);
            end
            system_filename = self.get_system_filename(sys.id);
            sys.to_file(system_filename);
            system_added = 1;
        end
        
        function volume_added = add_volume(self, subject, volume, options)
            % ADD_VOLUME Add a volume to a subject in the database.
            %
            % volume_added = add_volume(self, subject, volume, 'Param1', Value1, ...)
            % adds a volume to a subject in the database. By default, if the volume
            % already exists for the subject, it will raise an error.
            %
            % Inputs:
            %   self (fus.Database): The Database object.
            %   subject (fus.Subject): The subject to which the volume belongs.
            %   volume (fus.Volume): The volume to add.
            %
            % Optional Parameters:
            %   'on_conflict' (string): Specifies the action to take when the volume
            %       already exists for the subject. Possible values are 'OVERWRITE'
            %       (default), 'ERROR', or 'SKIP'.
            %   'format' (string): what format to save from
            %       ["mat","nii","both"]. Default "nii"
            %
            % Returns:
            %   volume_added (logical): True if the volume was added successfully,
            %       false if it was skipped or overwritten due to conflicts.
            %
            % SEE ALSO:
            %   VOLUME.TO_MAT, SUBJECT.TO_FILE
            arguments
                self fus.Database
                subject fus.Subject
                volume fus.Volume
                options.on_conflict (1,1) string {mustBeMember(options.on_conflict, ["overwrite", "error", "skip"])} = "error"
                options.format (1,1) string {mustBeMember(options.format, ["mat", "nii", "both"])} = "nii"
            end
            self.log.info('Adding Volume %s to Subject %s...', volume.id, subject.id)
            switch options.format
                case "mat"
                    ext = "mat";
                case "nii"
                    ext = "nii";
                case "both"
                    ext = ["mat", "nii"];
            end
            for ext_index = 1:length(ext)
                volume_filename = self.get_volume_filename(subject.id, volume.id, "ext", ext(ext_index));
                if exist(volume_filename, 'file')
                    switch options.on_conflict
                        case "error"
                            self.log.throw_error("add_volume:VolumeExists", "Volume %s is already attached to Subject", volume.id);
                        case "skip"
                            self.log.warning("Volume %s is already attached to Subject. Skipping.", volume.id);
                            volume_added = 0;
                            return
                        case "overwrite"
                            self.log.warning("Volume %s is already attached to Subject. Overwriting.", volume.id);
                        otherwise
                            self.log.throw_error("add_volume:InValidConflictOption", "Invalid conflict option '%s'", options.on_conflict);
                    end
                end
                switch ext(ext_index)
                    case "mat"
                        volume.to_mat(volume_filename);
                    case "nii"
                        volume.to_nifti(volume_filename);
                end
            end
            attrs = volume.attrs;
            attrs.id = volume.id;
            attrs.name = volume.name;
            attrs.dims = volume.dims;
            attrs.dim_names = [volume.coords.name];
            attrs_filename = self.get_volume_filename(subject.id, volume.id, "ext", "json");
            fus.util.struct2json(attrs, attrs_filename);
            if ~ismember(volume.id, subject.volumes)
                subject.volumes(end+1) = volume.id;
            end
            subject_filename = self.get_subject_filename(subject.id);
            subject.to_file(subject_filename);
            volume_added = 1;
            self.log.info('Added Volume %s to Subject %s...', volume.id, subject.id)
        end
        
        function session_id = choose_session(self, subject, options)
            % CHOOSE_SESSION Interactively select a session from local data.
            %
            % session_id = choose_session(self, subject, 'Param1', Value1, ...) allows
            % interactive selection of a session from local data associated with the
            % given subject.
            %
            % Inputs:
            %   self (fus.Database): The Database object.
            %   subject (fus.Subject): The subject for which to choose a session.
            %
            % Optional Parameters:
            %   'figure' (numeric): The figure handle for the GUI window. Default is -1.
            %   'graphical' (logical): Specifies whether to use graphical selection. Default is true.
            %
            % Returns:
            %   session_id (string): The ID of the selected session.
            arguments
                self fus.Database
                subject (1,1) fus.Subject
                options.figure = -1
                options.graphical logical = true
            end
            fig = options.figure;
            session_ids = self.get_session_ids(subject.id);
            if isempty(session_ids)
                self.log.error('No sessions found.')
                if options.graphical
                    fus.util.dlg_confirm(...
                        'No Sessions Found', ...
                        'No Sessions', ...
                        'figure', fig, ...
                        'Options', {'Ok'}, ...
                        'Icon', 'error');
                end
                session_id = string.empty;
                return
            end
            T = self.get_session_table(subject.id);
            T = sortrows(T, 'mdate', 'descend');
            data = T(:,{'name', 'date',  'mdate', 'transducers', 'targets', 'id'});
            names = {'Name', 'Session Date', 'Modified', 'Transducers', 'Targets', 'ID'};
            row = fus.util.TableSelector.select(...
                data, ...
                'column_names', names, ...
                'font_size', 14, ...
                'title', 'Select a Session', ...
                'position', [0.25, 0.25, 0.5, 0.5], ...
                'parent', options.figure, ...
                'graphical', options.graphical);
            if size(row,1) == 0
                session_id = string.empty;
            else
                session_id = row.id{1};
            end
        end
        
        function subject_id = choose_subject(self, options)
            % choose_subject Interactively select a subject from the database.
            %
            % subject_id = choose_subject(self, 'Param1', Value1, ...) allows interactive
            % selection of a subject from the database.
            %
            % Inputs:
            %   self (fus.Database): The Database object.
            %
            % Optional Parameters:
            %   'figure' (numeric): The figure handle for the GUI window. Default is -1.
            %   'graphical' (logical): Specifies whether to use graphical selection.
            %       Default is true.
            %
            % Returns:
            %   subject_id (string): The ID of the selected subject.
            arguments
                self fus.Database
                options.figure = -1
                options.graphical logical = true
            end
            fig = options.figure;
            subject_ids = self.get_subject_ids();
            if isempty(subject_ids)
                self.log.error('No subjects found.')
                if options.graphical
                    fus.util.dlg_confirm(...
                        'No Subjects Found', ...
                        'No Subjects', ...
                        'figure', fig, ...
                        'Options', {'Ok'}, ...
                        'Icon', 'error');
                end
                subject_id = string.empty;
                return
            end
            T = self.get_subject_table();
            data = T(:,{'id', 'name', 'sessions', 'date','mdate'});
            names = {'ID', 'Name', 'Sessions', 'Most Recent Session', 'Last Modified'};
            row = fus.util.TableSelector.select(...
                data, ...
                'column_names', names, ...
                'font_size', 14, ...
                'title', 'Select a Subject', ...
                'position', [0.25, 0.25, 0.5, 0.5], ...
                'parent', fig,...
                'graphical', options.graphical);
            if size(row,1) == 0
                subject_id = string.empty;
            else
                subject_id = row.id{1};
            end
        end
        
        function sys_id = get_connected_systems(self)
            % get_connected_systems Retrieve IDs of connected ultrasound systems.
            %
            % sys_id = get_connected_systems(self) returns the IDs of connected
            % ultrasound systems in the database.
            %
            % Inputs:
            %   self (fus.Database): The Database object.
            %
            % Returns:
            %   sys_id (string array): The IDs of connected ultrasound systems.
            arguments
                self fus.Database
            end
            sys_filename = self.get_connected_system_filename();
            if isfile(sys_filename)
                sys_id = split(string(strip(fileread(sys_filename))),",");
                sys_id = arrayfun(@strip, sys_id);
                sys_ids = self.get_system_ids();
                valid = ismember(sys_id, sys_ids);
                if ~all(valid)
                    self.log.throw_error("Invalid System ID %s. Valid IDs are [%s]", join(sys_id(valid),","), join(sys_ids,', '));
                end
            else
                sys_id = string.empty;
                self.log.warning("No system detected")
            end
        end
        
        function trans = get_connected_transducer(self, options)
            % get_connected_transducer Retrieve a connected transducer.
            %
            % trans = get_connected_transducer(self, 'Param1', Value1, ...) retrieves a
            % connected transducer from the database. If the transducer is not stored as
            % connected, it will prompt the user to select one.
            %
            % Inputs:
            %   self (fus.Database): The Database object.
            %
            % Optional Parameters:
            %   'save' (logical): Specifies whether to save the selected transducer as
            %       connected. Default is true.
            %
            % Returns:
            %   trans (fus.xdc.Transducer): The selected connected transducer.
            arguments
                self fus.Database
                options.save logical = true
            end
            filename = self.get_connected_transducer_filename();
            if exist(filename, 'file')
                transducer_id = strip(fileread(filename));
                trans = self.load_transducer(transducer_id);
            else
                transducers = self.load_transducer("all");
                [trans, ok] = transducers.select();
                if ~ok
                    self.log.throw_error('get_connected_transducer:NoTransducerSelected', 'You must select a transducer');
                end
                if options.save
                    self.set_connnected_transducer(trans);
                end
            end
        end
        
        function plan_ids = get_plan_ids(self)
            % get_plan_ids Retrieve plan IDs from the database.
            %
            % plan_ids = get_plan_ids(self) retrieves plan IDs stored in the database.
            %
            % Inputs:
            %   self (fus.Database): The Database object.
            %
            % Returns:
            %   plan_ids (string array): The plan IDs from the database.
            arguments
                self fus.Database
            end
            plans_filename = self.get_plans_filename();
            if isfile(plans_filename)
                plans_data = jsondecode(fileread(plans_filename));
                plan_ids = string(plans_data.plan_ids);
            else
                plan_ids = string.empty;
            end 
        end
        
        function session_ids = get_session_ids(self, subject_id)    
            % get_session_ids Retrieve session IDs for a subject from the database.
            %
            % session_ids = get_session_ids(self, subject_id) retrieves session IDs
            % associated with the specified subject from the database.
            %
            % Inputs:
            %   self (fus.Database): The Database object.
            %   subject_id (string): The ID of the subject for which to retrieve session
            %       IDs.
            %
            % Returns:
            %   session_ids (string array): The session IDs for the subject from the
            %       database.
            arguments
                self fus.Database
                subject_id (1,:) string {mustBeValidVariableName}
            end
            sessions_filename = self.get_sessions_filename(subject_id);
            if isfile(sessions_filename)
                session_data = jsondecode(fileread(sessions_filename));
                session_ids = string(session_data.session_ids);
            else
                session_ids = string.empty;
            end
        end
        
        function ids_by_plan = get_solutions(self, subject_id, session_id)
            % get_solutions Retrieve solution IDs by plan and target from the database.
            %
            % ids_by_plan = get_solutions(self, subject_id, session_id) retrieves
            % solution IDs organized by plan and target associated with the specified
            % subject and session from the database.
            %
            % Inputs:
            %   self (fus.Database): The Database object.
            %   subject_id (string): The ID of the subject.
            %   session_id (string): The ID of the session.
            %
            % Returns:
            %   ids_by_plan (struct): A structure containing solution IDs organized by
            %       plan and target.
            arguments
                self fus.Database
                subject_id (1,1) string {mustBeValidVariableName}
                session_id (1,1) string {mustBeValidVariableName}
            end
            solutions_filename = get_solutions_filename(self, subject_id, session_id);
            if isfile(solutions_filename)
                ids_by_plan = jsondecode(fileread(solutions_filename));
                plan_ids = reshape(string(fieldnames(ids_by_plan)), 1, []);
                for i = 1:length(plan_ids)
                    plan_id = plan_ids(i);
                    ids_by_plan.(plan_id) = reshape(string(ids_by_plan.(plan_id)),1,[]);
                end
            else
                ids_by_plan = struct();
            end
        end
        
        function subject_ids = get_subject_ids(self)
            % get_subject_ids Retrieve subject IDs from the database.
            %
            % subject_ids = get_subject_ids(self) retrieves subject IDs from the
            % database.
            %
            % Inputs:
            %   self (fus.Database): The Database object.
            %
            % Returns:
            %   subject_ids (string array): The subject IDs from the database.
            arguments
                self fus.Database
            end
            subjects_filename = self.get_subjects_filename();
            if isfile(subjects_filename)
                subject_data = jsondecode(fileread(subjects_filename));
                subject_ids = string(subject_data.subject_ids);
            else
                subject_ids = string.empty;
            end
        end
        
        function session_table = get_session_table(self, subject_id, options)
            % get_session_table Retrieve session information as a table from the database.
            %
            % session_table = get_session_table(self, subject_id, 'Param1', Value1, ...)
            % retrieves session information organized as a table for the specified
            % subject from the database.
            %
            % Inputs:
            %   self (fus.Database): The Database object.
            %   subject_id (string): The ID of the subject.
            %
            % Optional Parameters:
            %   'session_ids' (string array): The session IDs to retrieve. Default is
            %       all session IDs for the subject.
            %
            % Returns:
            %   session_table (table): A table containing session information.
            arguments
                self fus.Database
                subject_id (1,1) string
                options.session_ids (1,:) string = self.get_session_ids(subject_id);
            end
            t = struct(...
                'name', {}, ...
                'id', {}, ...
                'date', {}, ...
                'mdate', {}, ...
                'transducers', {}, ...
                'targets', {});
            session_ids = options.session_ids;
            for i = 1:length(session_ids)
                session_id = session_ids{i};
                session_info = self.load_session_info(subject_id, session_id);
                t(i) = struct(...
                    'name', session_info.name, ...
                    'id', session_info.id, ...
                    'date', datestr(session_info.date),...
                    'mdate', datestr(session_info.date_modified), ...
                    'transducers', sum(arrayfun(@(x)~isempty(x.id),session_info.transducer)), ...
                    'targets', numel(session_info.targets));
            end
            session_table = struct2table(t,'AsArray', true);
        end
        
        function subject_table = get_subject_table(self, options)
            % get_subject_table Retrieve subject information as a table from the database.
            %
            % subject_table = get_subject_table(self, 'Param1', Value1, ...) retrieves
            % subject information organized as a table from the database.
            %
            % Inputs:
            %   self (fus.Database): The Database object.
            %
            % Optional Parameters:
            %   'subject_ids' (string array): The subject IDs to retrieve. Default is
            %       all subject IDs in the database.
            %
            % Returns:
            %   subject_table (table): A table containing subject information.
            arguments
                self fus.Database
                options.subject_ids (1,:) string = self.get_subject_ids
            end
            subject_ids = options.subject_ids;
            t = struct(...
                    'id', {}, ...
                    'name', {}, ...
                    'sessions', {}, ...
                    'date', {},...
                    'mdate', {});
            for i = 1:length(subject_ids)
                subject_id = subject_ids{i};
                subject = self.load_subject(subject_id, silent=true);
                session_ids = self.get_session_ids(subject_ids{i});
                session_info = arrayfun(@(session_id)self.load_session_info(subject_id, session_id), session_ids);
                date = max(arrayfun(@(info)info.date,session_info));
                mdate = max(arrayfun(@(info)info.date_modified,session_info));
                n_sessions = length(session_info);
                t(i) = struct(...
                    'id', subject_ids{i}, ...
                    'name', subject.name, ...
                    'sessions', n_sessions, ...
                    'date', datestr(date),...
                    'mdate', datestr(mdate));
            end
            subject_table = struct2table(t, 'AsArray', true);
        end
        
        function sys_ids = get_system_ids(self)
            % get_system_ids Retrieve system IDs from the database.
            %
            % sys_ids = get_system_ids(self) retrieves system IDs from the database.
            %
            % Inputs:
            %   self (fus.Database): The Database object.
            %
            % Returns:
            %   sys_ids (string array): The system IDs from the database.
            arguments
                self fus.Database
            end
            systems_filename = self.get_systems_filename;
            if isfile(systems_filename)
                sys_data = jsondecode(fileread(systems_filename));
                sys_ids = sys_data.system_ids;
            else
                sys_ids = string.empty;
            end
        end
        
        function sys_info = get_system_info(self, sys_id)
            % get_system_info Retrieve information for ultrasound systems from the database.
            %
            % sys_info = get_system_info(self, 'Param1', Value1, ...) retrieves
            % information for ultrasound systems stored in the database.
            %
            % Inputs:
            %   self (fus.Database): The Database object.
            %
            % Optional Parameters:
            %   'sys_id' (string array): The system IDs to retrieve information for.
            %       Default is connected systems.
            %
            % Returns:
            %   sys_info (struct array): An array of structures containing system
            %       information.
            arguments
                self fus.Database
                sys_id (1,:) string {mustBeValidVariableName} = self.get_connected_systems
            end
            for i = 1:numel(sys_id)
                sys_filename = self.get_system_filename(sys_id(i));
                if ~isfile(sys_filename)
                    self.log.throw_error("Cannot load %s. %s not found.", sys_id(i), sys_filename);
                end
                s = jsondecode(fileread(sys_filename));
                sys_info(i) = struct('id', string(s.id), 'name', string(s.name), 'class', string(s.class));
            end
        end
        
        function transducer_ids = get_transducer_ids(self)
            % get_transducer_ids Retrieve transducer IDs from the database.
            %
            % transducer_ids = get_transducer_ids(self) retrieves transducer IDs from
            % the database.
            %
            % Inputs:
            %   self (fus.Database): The Database object.
            %
            % Returns:
            %   transducer_ids (string array): The transducer IDs from the database.
            %
            arguments
                self fus.Database
            end
            transducers_filename = self.get_transducers_filename();
            if isfile(transducers_filename)
                index = jsondecode(fileread(transducers_filename));
                transducer_ids = string(index.transducer_ids);
            else
                transducer_ids = string.empty;
            end
        end
        
        function filelist = list_files(self, options)
            % list_files List files in the database directory.
            %
            % filelist = list_files(self, 'Param1', Value1, ...) lists files in the
            % database directory and returns them as a cell array of strings.
            %
            % Inputs:
            %   self (fus.Database): The Database object.
            %
            % Optional Parameters:
            %   'indent' (double): The indentation level for displaying the file
            %       structure. Default is 0.
            %   'recursive' (logical): Flag to enable recursive listing of files.
            %       Default is true.
            %   'depth' (double): Maximum depth for recursive listing. Default is inf.
            %   'ignore' (string array): Regular expressions to ignore files or
            %       directories matching these patterns. Default is "^\.*".
            %   'tabwidth' (double): Width of each tab character for indentation.
            %       Default is 2.
            %
            % Returns:
            %   filelist (cell array of strings): List of files in the database
            %       directory.
            arguments
                self fus.Database
                    options.indent (1,1) double {mustBeInteger} = 0
                    options.recursive (1,1) logical = true
                    options.depth (1,1) double = inf
                    options.ignore (1,:) string = "^\.*"
                    options.tabwidth (1,1) double {mustBeInteger} = 2
            end
            args = fus.util.struct2args(options);
            filelist = fus.util.list_dir(self.path, args{:});
        end
        
        function treatment_plan = load_plan(self, plan_id)
            % load_plan Load a treatment plan from the database.
            %
            % treatment_plan = load_plan(self, plan_id) loads a treatment plan with
            % the specified plan ID from the database.
            %
            % Inputs:
            %   self (fus.Database): The Database object.
            %   plan_id (string): The ID of the treatment plan to load.
            %
            % Returns:
            %   treatment_plan (fus.treatment.Plan): The loaded treatment plan.
            arguments
                self fus.Database
                plan_id (1,1) string {mustBeValidVariableName}
            end
            plan_filename = self.get_plan_filename(plan_id);
            if isfile(plan_filename)
                treatment_plan = fus.treatment.Plan.from_file(plan_filename);
            else
                self.log.throw_error("Plan %s not found", plan_id);
            end
        end
        
        function treatment_plans = load_all_plans(self)
            % load_all_plans Load all treatment plans from the database.
            %
            % treatment_plans = load_all_plans(self) loads all treatment plans stored
            % in the database and returns them as an array of TreatmentPlan objects.
            %
            % Inputs:
            %   self (fus.Database): The Database object.
            %
            % Returns:
            %   treatment_plans (fus.treatment.Plan array): An array of loaded treatment
            %       plans.
            arguments
                self fus.Database
            end
            plan_ids = self.get_plan_ids();
            treatment_plans = arrayfun(@(id)self.load_plan(id), reshape(plan_ids, 1, []));
        end
        
        function data = load_session_solutions(self, session, options)
            % load_session_solutions Load solutions for a session.
            %
            % data = load_session_solutions(self, session, options) loads solutions
            % associated with a session and returns relevant data for visualization.
            %
            % Inputs:
            %   self (fus.Database): The Database object.
            %   session (fus.Session): The session for which solutions are loaded.
            %   options (struct, optional): Optional parameters.
            %       - plans (fus.treatment.Plan array, default: all plans in the database):
            %         An array of TreatmentPlan objects to use for loading solutions.
            %       - progressbar (logical, default: true): Whether to display a
            %         progress bar during loading.
            %       - figure (double, default: -1): The figure handle for progress
            %         bar display.
            %
            % Returns:
            %   data (struct): A structure containing loaded data for visualization.
            arguments
                self fus.Database
                session fus.Session
                options.plans (1,:) fus.treatment.Plan = self.load_all_plans
                options.progressbar = true
                options.figure = -1
            end
            if options.progressbar
                p = fus.util.ProgressBar("figure", options.figure, "title", sprintf("Loading %s...", session.name));
            end
            session_id = session.id;
            subject_id = session.subject_id;
            self.log.info('Loading Session...')
            if options.progressbar;p.update(0.1, "Loading Session...");end
            scene = session.to_scene("id", "raw", "Name", "Raw");
            base_scene = scene.transform_base("dx", 1, "units", "mm");
            base_scene.id = "mri";
            base_scene.name = "MRI";
            base_scene.volumes.id = "mri";
            base_scene.volumes.name = "MRI";
            mri_cmap = base_scene.colormaps;
            mri_cmap.id = "mri";
            pnp_cmap = fus.ColorMapper(...
                "id", "pnp", ...
                cmap=parula(256), ...
                clim_in=[0 1], ...
                alim_in=[0.1, 0.4], ...
                alim_out=[0, 0.6]);
            ita_cmap = fus.ColorMapper(...
                "id", "ita", ...
                cmap=jet(256), ...
                clim_in=[0 1], ...
                alim_in=[0, 1], ...
                alim_out=[0, 0.6]);
            cmaps = [mri_cmap, pnp_cmap, ita_cmap];
            plans = options.plans;
            plan_ids = [plans.id];
            target_ids = [session.targets.id];   
            init_plan_id = plan_ids(1);
            init_target_id = session.targets(end).id;   
            session_solutions = self.get_solutions(subject_id, session_id);
            solved_plan_ids = string(fieldnames(session_solutions));
            solved_plan_ids = solved_plan_ids(ismember(solved_plan_ids, plan_ids)); % filter out custom solutions that don't have stored plans
            most_recent = datetime(2000,1,1);
            self.log.info('Loading Solutions...')
            if options.progressbar;p.update(0.2, "Loading Solutions...");end
            solutions = struct();
            for i = 1:length(solved_plan_ids)
                if options.progressbar;p.update(0.2 + 0.3*i/length(solved_plan_ids));end
                solved_plan_id = solved_plan_ids(i);
                plan_solutions = arrayfun(@(id)self.load_solution(session, solved_plan_id, id), session_solutions.(solved_plan_id));
                creation_times = [plan_solutions.created_on];
                if any(creation_times > most_recent)
                    most_recent = max(creation_times);
                    init_plan_id = solved_plan_id;
                    solved_target_ids = [plan_solutions.target_id];
                    init_target_id = solved_target_ids(find(creation_times==most_recent, 1, 'first'));
                end
                solutions.(solved_plan_id) = plan_solutions;
            end
            scenes = struct();
            solution_output = struct();
            for i = 1:length(plan_ids)
                plan_id = plan_ids(i);
                plan = plans.by_id(plan_id);
                self.log.info('Building Scenes for plan %s (%s)', plan_id, plan.name)
                sim_scene = plan.transform_sim_scene(base_scene);
                sim_scenes.(plan_id) = sim_scene;
                plan_scenes = struct();
                for j = 1:length(target_ids)
                    target_id = target_ids(j);
                    target = session.targets.by_id(target_id);
                    self.log.info('Building Scenes for target %s (%s)', target_id, target.name)
                    if options.progressbar;p.update(0.5 + 0.5*(i-1+(j/length(target_ids)))/length(plan_ids), sprintf('Transforming %s/%s', plan.name, target.name));end
                    target_scenes = struct();
                    for view_id = ["head", "sim"]
                        switch view_id
                            case "head"
                                mri_scene = base_scene.rescale("mm");
                            case "sim"
                                mri_scene = sim_scene.rescale("mm");
                        end
                        mri_scene.id = "mri";
                        mri_scene.name = "MRI Only";
                        mri_scene.targets = mri_scene.targets.by_id(target_id);
                        mri_volume = mri_scene.volumes(1).rescale("mm");
                        mri_scene.volumes = mri_volume;
                        mri_scene.colormaps = mri_cmap;
                        view_scenes = mri_scene;
                        if isfield(solutions, plan_id) && ismember(target_id, [solutions.(plan_id).target_id])
                            self.log.info('Transforming Solution to view %s...', view_id)
                            solution = solutions.(plan_id).by_target(target_id);
                            output = self.load_solution_output(session, plan_id, target_id);
                            solution_output.(plan_id).(target_id) = output;
                            new_scenes = solution.to_scenes(output, mri_scene, "cmaps", [cmaps]);
                            view_scenes = [mri_scene new_scenes];
                        end
                        target_scenes.(view_id) = view_scenes;
                    end
                    plan_scenes.(target_id) = target_scenes;
                end
                scenes.(plan_id) = plan_scenes;
            end
            data.scenes = scenes;
            data.cmaps = cmaps;
            data.sim_scenes = sim_scenes;
            data.solutions = solutions;
            data.output = solution_output;
            data.most_recent = struct('plan_id', init_plan_id, 'target_id', init_target_id);
            if options.progressbar;p.close();end
        end
        
        function session = load_session(self, subject, session_id, options)
            % load_session Load a session from the database.
            %
            % session = load_session(self, subject, session_id) loads a session
            % specified by its ID from the database and returns a Session object.
            %
            % Inputs:
            %   self (fus.Database): The Database object.
            %   subject (fus.Subject): The Subject to which the session belongs.
            %   session_id (string): The ID of the session to load.
            %
            % Optional Parameters:
            %   'deface' (logical): Deface the volume. Default false
            %
            % Returns:
            %   session (fus.Session): The loaded Session object.
            arguments
                self fus.Database
                subject fus.Subject
                session_id (1,1) string {mustBeValidVariableName}
                options.deface (1,1) logical = false
                options.skip_empty_targets (1,1) logical = true
            end
            self.log.info("Loading session %s...", session_id);
            s = self.load_session_info(subject.id, session_id);
            volume = self.load_volume(subject, s.volume);
            if isempty(s.transducer) || isempty(s.transducer.id)
                trans = fus.xdc.Transducer.empty;
            else
                trans = self.load_transducer(s.transducer.id);
                trans.rescale("mm");
                trans.matrix = s.transducer.matrix;
            end
            targets = fus.Point.from_struct(s.targets);
            if options.skip_empty_targets
                targets = targets([targets.name] ~= "");
            end
            markers = fus.Point.from_struct(s.markers);
            if options.deface
                nasion = markers(~cellfun(@isempty,regexpi([markers.id], '(nasion|nose)', 'once')));
                if ~isempty(nasion)
                    volume = fus.seg.deface(volume, "nasion", nasion.position);
                else
                    volume = fus.seg.deface(volume);
                end
            end
            session = fus.Session(...
                "id", s.id, ...
                "subject_id", subject.id, ...
                "name", s.name, ...
                "date", s.date, ...
                "targets", targets, ...
                "markers", markers, ...
                "volume", volume, ...
                "transducer", trans, ...
                "attrs", s.attrs, ...
                "date_modified", s.date_modified);
            if ~isfield(s, 'subject_id')
                self.log.warning('Adding subject_id to session');
                session.to_file(self.get_session_filename(subject.id, session.id));
            end
            self.log.info("Loaded session %s", session_id);
        end
        
        function session_info = load_session_info(self, subject_id, session_id)
            % load_session_info Load session information from the database.
            %
            % session_info = load_session_info(self, subject_id, session_id) loads
            % information about a session specified by its ID from the database
            % and returns it as a structure.
            %
            % Inputs:
            %   self (fus.Database): The Database object.
            %   subject_id (string): The ID of the subject to which the session belongs.
            %   session_id (string): The ID of the session for which to load information.
            %
            % Returns:
            %   session_info (struct): A structure containing information about the session.
            arguments
                self fus.Database
                subject_id (1,1) string {mustBeValidVariableName}
                session_id (1,1) string {mustBeValidVariableName}
            end
            session_filename = self.get_session_filename(subject_id, session_id);
            s = jsondecode(fileread(session_filename));
            field_order = ["id", "subject_id", "name", "date", "targets", "markers", "volume", "transducer", "attrs", "date_modified"];
            if ~isfield(s, "subject_id") || isstruct(s.subject_id) || ~isequal(string(fieldnames(s))', field_order)
                s.subject_id = subject_id;
                s = orderfields(s, field_order);
                fus.util.struct2json(s, session_filename);
            end
            s.date = datetime(s.date);
            s.date_modified = datetime(s.date_modified);
            session_info = s;
        end
        
        function varargout = load_solution(self, session, plan_id, target_id)
            % LOAD_SOLUTION Load a treatment solution from the database.
            % solution = load_solution(self, session, plan_id, target_id) 
            % [solution, output] = load_solution(self, session, plan_id, target_id) 
            %
            % LOAD_SOLUTION loads a treatment solution specified by its plan ID 
            % and target ID for a given session from the database and returns
            % it as a TreatmentSolution object.
            %
            % Inputs:
            %   self (fus.Database): The Database object.
            %   session (fus.Session): The Session object to which the solution belongs.
            %   plan_id (string): The ID of the treatment plan associated with the solution.
            %   target_id (string): The ID of the target associated with the solution.
            %
            % Returns:
            %   solution (fus.treatment.Solution): The loaded treatment solution.
            %   output (struct): Solution output
            arguments
                self fus.Database
                session (1,1) fus.Session
                plan_id (1,1) string {mustBeValidVariableName}
                target_id (1,1) string {mustBeValidVariableName}
            end
            subject_id = session.subject_id;
            session_id = session.id;
            json_filename = self.get_solution_filename(subject_id, session_id, plan_id, target_id, "json");
            mat_filename = self.get_solution_filename(subject_id, session_id, plan_id, target_id, "mat");
            if ~isfile(json_filename) || ~isfile(mat_filename)
                self.log.throw_error("load_solution:NotFound", "Solution %s/%s for Subject %s Session %s not found", plan_id, target_id, subject_id, session_id);
            end
            s = jsondecode(fileread(json_filename));
            if isfield(s, "analysis")
                analysis_filename = self.get_solution_filename(subject_id, session_id, plan_id, target_id, "analysis.json");
                fus.util.struct2json(s.analysis, analysis_filename)
                s = rmfield(s, "analysis");
                fus.util.struct2json(s, json_filename);
            end
            s.transducer = session.transducer.to_struct();
            solution = fus.treatment.Solution.from_struct(s);
            varargout{1} = solution;
            if nargout > 1
                varargout{2} = self.load_solution_output(session, plan_id, target_id);
            end
        end
        
        function analysis = load_solution_analysis(self, session, plan_id, target_id)
            % LOAD_SOLUTION_ANALYSIS Load a solution analysis from the database.
            %
            % analysis = load_solution_analysis(self, session, plan_id, target_id) loads
            % the analysis specified by its plan ID and target ID for a
            % given session from the database and returns it as a struct
            %
            % Inputs:
            %   self (fus.Database): The Database object.
            %   session (fus.Session): The Session object to which the solution belongs.
            %   plan_id (string): The ID of the treatment plan associated with the solution.
            %   target_id (string): The ID of the target associated with the solution.
            %
            % Returns:
            %   analysis (struct): The analysis results
            arguments
                self fus.Database
                session (1,1) fus.Session
                plan_id (1,1) string {mustBeValidVariableName}
                target_id (1,1) string {mustBeValidVariableName}
            end
            subject_id = session.subject_id;
            session_id = session.id;
            analysis_filename = self.get_solution_filename(subject_id, session_id, plan_id, target_id, "analysis.json");
            if ~isfile(analysis_filename)
                json_filename = self.get_solution_filename(subject_id, session_id, plan_id, target_id, "json");
                if isfile(json_filename)
                    s = jsondecode(fileread(json_filename));
                    if isfield(s, "analysis")
                        analysis = s.analysis;
                        fus.util.struct2json(s.analysis, analysis_filename)
                        s = rmfield(s, "analysis");
                        fus.util.struct2json(s, json_filename);
                    else
                        self.log.throw_error("load_solution_analysis:NotFound", "Analysis for Solution %s/%s for Subject %s Session %s not found", plan_id, target_id, subject_id, session_id);        
                    end
                else
                    self.log.throw_error("load_solution_analysis:NotFound", "Analysis for Solution %s/%s for Subject %s Session %s not found", plan_id, target_id, subject_id, session_id);
                end
            else
                analysis = jsondecode(fileread(analysis_filename));
            end
        end
        
        function output = load_solution_output(self, session, plan_id, target_id)
            % LOAD_SOLUTION_OUTPUT Load a treatment solution output from the database.
            %
            % solution = load_solution_ouput(self, session, plan_id, target_id) loads
            % a treatment solution's output specified by its plan ID and target ID for a
            % given session from the database and returns it as a struct
            %
            % Inputs:
            %   self (fus.Database): The Database object.
            %   session (fus.Session): The Session object to which the solution belongs.
            %   plan_id (string): The ID of the treatment plan associated with the solution.
            %   target_id (string): The ID of the target associated with the solution.
            %
            % Returns:
            %   output: struct with pnp, intensity, and analysis fields
            arguments
                self fus.Database
                session (1,1) fus.Session
                plan_id (1,1) string {mustBeValidVariableName}
                target_id (1,1) string {mustBeValidVariableName}
            end
            subject_id = session.subject_id;
            session_id = session.id;
            analysis = self.load_solution_analysis(session, plan_id, target_id);
            mat_filename = self.get_solution_filename(subject_id, session_id, plan_id, target_id, "mat");
            if ~isfile(mat_filename)
                self.log.throw_error("load_solution:NotFound", "Solution %s/%s for Subject %s Session %s not found", plan_id, target_id, subject_id, session_id);
            end
            mat_data = load(mat_filename);
            if isa(mat_data.pnp, "fus.Volume")
                mat_data.pnp = mat_data.pnp.to_struct();
                mat_data.intensity = mat_data.intensity.to_struct();
                save("mat_filename", "-struct", "mat_data");
            end 
            output.pnp = fus.Volume.from_struct(mat_data.pnp);
            output.intensity = fus.Volume.from_struct(mat_data.intensity);
            output.analysis = analysis;
            trans_matrix = session.transducer.get_matrix("units", output.pnp.get_units);
            if ~isequal(output.pnp(1).matrix, trans_matrix)
                self.log.warning("Assigning transducer matrix to solution")
                for i = 1:length(output.pnp)
                    output.pnp(i).matrix = trans_matrix;
                    output.intensity(i).matrix = trans_matrix;
                end
            end
        end
              
        function subject = load_subject(self, subject_id, options)
            % load_subject Load a subject from the database.
            %
            % subject = load_subject(self, subject_id, options) loads a subject
            % specified by its ID from the database and returns it as a Subject
            % object.
            %
            % Inputs:
            %   self (fus.Database): The Database object.
            %   subject_id (string or 1-D string array): The ID(s) of the subject(s)
            %       to load.
            %   options (optional): Additional options for loading the subject.
            %       - silent (logical): If true, suppress logging messages (default
            %         is false).
            %
            % Returns:
            %   subject (fus.Subject): The loaded subject.
            arguments
                self fus.Database
                subject_id (1,:) string {mustBeValidVariableName}
                options.silent (1,1) logical = false
            end
            subject_filename = self.get_subject_filename(subject_id);
            if ~options.silent
                self.log.info("Loading subject %s from %s...", subject_id, subject_filename);
            end
            subject = fus.Subject.from_file(subject_filename);
            if ~options.silent
                self.log.info("Loaded subject %s", subject_id);
            end
        end
        
        function volume = load_volume(self, subject, volume_id, options)
            % load_volume Load a volume from the database.
            %
            % volume = load_volume(self, subject, volume_id) loads a volume specified
            % by its ID from the database and returns it as a Volume object.
            %
            % Inputs:
            %   self (fus.Database): The Database object.
            %   subject (fus.Subject): The Subject object to which the volume belongs.
            %   volume_id (string): The ID of the volume to load.
            %
            % Optional Parameters:
            %   'ext': file format from "nii" or "mat". Default "nii"
            %
            % Returns:
            %   volume (fus.Volume): The loaded volume.
            %
            % See also:
            %   fus.Volume.from_file
            arguments
                self fus.Database
                subject fus.Subject
                volume_id (1,1) string {mustBeValidVariableName}
                options.ext (1,1) string {mustBeMember(options.ext, ["mat", "nii"])} = "nii"
            end
            volume_filename = self.get_volume_filename(subject.id, volume_id, "ext", options.ext);
            switch options.ext
                case "mat"
                    if isfile(volume_filename)
                        self.log.info("Loading %s...", volume_filename);
                        volume = fus.Volume.from_file(volume_filename);
                    else
                        self.log.throw_error("Volume %s not found. %s does not exist", volume_id, volume_filename);
                    end
                case "nii"
                    attrs = self.load_volume_attrs(subject, volume_id);
                    s = struct();
                    meta_fields = ["id","name","dims","dim_names"];
                    for i = 1:length(meta_fields)
                        f = meta_fields(i);
                        if isfield(attrs, f)
                            s.(f) = attrs.(f);
                            attrs = rmfield(attrs,f);
                        end
                    end
                    args = fus.util.struct2args(s);
                    if isfile(volume_filename)
                        self.log.info("Loading %s...", volume_filename);
                        volume = fus.Volume.from_nifti(volume_filename, args{:}, "attrs", attrs);
                    else
                        if all(isfield(attrs, ["rows","columns","frames"]))
                            coords = arrayfun(@(dim, name, f)fus.Axis((0:attrs.(f)-1)-((attrs.(f)-1)/2), dim, "name", name, "units", "mm"), string(s.dims), string(s.dim_names), ["rows";"columns";"frames"]);
                            volume = fus.Volume(zeros(attrs.rows, attrs.columns, attrs.frames), coords, "id", s.id, "name", s.name, "attrs", attrs);
                            self.log.warning("Volume %s not found. %s does not exist. Loading Blank", volume_id, volume_filename);
                        else
                            self.log.throw_error("Volume %s not found. %s does not exist", volume_id, volume_filename);
                        end
                    end
            end
            
        end
        
        function attrs = load_volume_attrs(self, subject, volume_ids)
            % load_volume_attrs Load attributes of volumes from the database.
            %
            % attrs = load_volume_attrs(self, subject, volume_ids) loads attributes of
            % volumes specified by their IDs from the database and returns them as an
            % array of structs.
            %
            % Inputs:
            %   self (fus.Database): The Database object.
            %   subject (fus.Subject): The Subject object to which the volumes belong.
            %   volume_ids (string): An optional array of volume IDs to load attributes
            %       from. If not specified, it loads attributes for all volumes in the
            %       subject.
            %
            % Returns:
            %   attrs (struct[]): An array of structs containing attributes of the
            %       loaded volumes.
            arguments
                self fus.Database
                subject fus.Subject
                volume_ids (1,:) string {mustBeValidVariableName} = subject.volumes
            end
            if isempty(volume_ids)
                attrs = struct.empty;
            end
            for i = 1:length(volume_ids)
                attrs_filename = self.get_volume_filename(subject.id, volume_ids(i), "ext", "json");
                if isfile(attrs_filename)
                    attrs(i) = jsondecode(fileread(attrs_filename));
                else
                    volume_filename = self.get_volume_filename(subject.id, volume_ids(i), "ext", "mat");
                    if isfile(volume_filename)
                        s = load(volume_filename, 'attrs');
                        attrs(i) = s.attrs;
                    else
                        attrs(i) = struct();
                    end
                end
            end
        end
        
        function standoff = load_standoff(self, transducer_id, standoff_id)
            % LOAD_STANDOFF Load a standoff from the database.
            %   standoff = LOAD_STANDOFF(transducer_id, standoff_id) loads a standoff
            %
            % Inputs:
            %   self (fus.Database): The Database object.
            %   transducer_id (string): The ID of the transducer to which the standoff
            %       belongs.
            %   standoff_id (string): The ID of the standoff to load.
            %
            % Returns:
            %   standoff (fus.xdc.Standoff): The loaded standoff.
            arguments
                self fus.Database
                transducer_id (1,1) string {mustBeValidVariableName}
                standoff_id (1,1) string {mustBeValidVariableName} = "standoff"
            end
            standoff_filename = self.get_standoff_filename(transducer_id, standoff_id);
            if ~isfile(standoff_filename)
                self.log.throw_error("Standoff %s not found. %s does not exist", standoff_id, standoff_filename);
            end
            standoff = fus.xdc.Standoff.from_file(standoff_filename);
        end

        function sys = load_system(self, sys_id)
            % load_system Load an UltrasoundSystem from the database.
            %
            % sys = load_system(self, sys_id) loads an UltrasoundSystem object specified
            % by its ID from the database and returns it.
            %
            % Inputs:
            %   self (fus.Database): The Database object.
            %   sys_id (string): The ID of the UltrasoundSystem to load. If not
            %       specified, it loads the system specified by the connected systems.
            %
            % Returns:
            %   sys (fus.sys.UltrasoundSystem): The loaded UltrasoundSystem object.
            %
            % Raises:
            %   - Throws an error if no system ID is specified.
            %   - Throws an error if the system with the specified ID is not found.
            arguments
                self fus.Database
                sys_id (1,:) = self.get_connected_systems
            end
            if isempty(sys_id)
                self.log.throw_error("No System Specified.");
            end
            sys_filename = self.get_system_filename(sys_id);
            if ~isfile(sys_filename)
                self.log.throw_error("Cannot load %s. %s not found.", sys_id, sys_filename);
            end
            s = jsondecode(fileread(sys_filename));
            sys = fus.sys.UltrasoundSystem.from_struct(s);
        end
        
        function trans = load_transducer(self, transducer_id)
            % load_transducer Load a transducer from the database.
            %
            % trans = load_transducer(self, transducer_id) loads a transducer specified
            % by its ID from the database and returns it as an fus.xdc.Transducer object.
            %
            % Inputs:
            %   self (fus.Database): The Database object.
            %   transducer_id (string): The ID of the transducer to load. If "all" is
            %       provided, it loads all transducers in the database.
            %
            % Returns:
            %   trans (fus.xdc.Transducer or array of fus.xdc.Transducer): The loaded transducer(s).
            %
            % Raises:
            %   - Throws an error if the transducer with the specified ID is not found.
            arguments
                self fus.Database
                transducer_id (1,1) string {mustBeValidVariableName}
            end
            switch transducer_id
                case "all"
                    transducer_ids = self.get_transducer_ids();
                    for i = 1:length(transducer_ids)
                        id = transducer_ids{i};
                        trans(i) = self.load_transducer(id); 
                    end
                otherwise
                    filename =  fullfile(self.path, 'transducers', transducer_id, sprintf('%s.json', transducer_id));            
                    trans = fus.xdc.Transducer.from_file(filename);
            end
        end
        
        function set_connnected_system(self, sys, options)
            % set_connected_system Set the connected ultrasound systems.
            %
            % set_connected_system(self, sys, 'param1', value1, 'param2', value2, ...)
            % sets the connected ultrasound systems in the database. You can specify
            % whether to add systems if they are missing in the database.
            %
            % Inputs:
            %   self (fus.Database): The Database object.
            %   sys (array of fus.sys.UltrasoundSystem): An array of UltrasoundSystem objects
            %       representing the systems to be set as connected.
            %
            % Optional Parameters:
            %  'add_if_missing' (logical): If true, systems not found in the
            %       database will be added. If false (default), an error will be thrown
            %       for invalid system IDs.
            %
            % Raises:
            %   Throws an error if any specified system ID is invalid and
            %    'add_if_missing' is false.
            arguments
                self fus.Database 
                sys (1,:) fus.sys.UltrasoundSystem
                options.add_if_missing (1,1) logical = false
            end
            sys_ids = self.get_system_ids();
            valid = ismember([sys.id], sys_ids);
            if ~all(valid)
                if options.add_if_missing
                    self.add_system(sys(~valid));
                else
                    self.log.throw_error("Invalid System ID %s. Valid IDs are [%s]", join([sys(~valid).id],","), join(sys_ids,', '));
                end
            end
            connected_sys_filename = self.get_connected_system_filename();
            fid = fopen(connected_sys_filename, 'w');
            fwrite(fid, join([sys.id],","));
            fclose(fid);
        end

        function set_connected_transducer(self, trans, options)
            % set_connected_transducer Set the connected transducer.
            %
            % set_connected_transducer(self, trans, 'param1', value1, 'param2', value2, ...)
            % sets the connected transducer in the database. You can specify whether to
            % add the transducer if it is missing in the database.
            %
            % Inputs:
            %   self (fus.Database): The Database object.
            %   trans (fus.xdc.Transducer): An fus.xdc.Transducer object representing the transducer to
            %       be set as connected.
            %   Optional Parameters:
            %     'add_if_missing' (logical): If true, the transducer not found in the
            %       database will be added. If false (default), an error will be thrown
            %       for an invalid transducer ID.
            %
            % Raises:
            %   Throws an error if the specified transducer ID is invalid and
            %   'add_if_missing' is false.
            arguments
                self fus.Database
                trans (1,1) fus.xdc.Transducer
                options.add_if_missing (1,1) logical = false
            end
            trans_ids = self.get_transducer_ids();
            if ~ismember(trans.id, trans_ids)
                if options.add_if_missing
                    self.add_transducer(trans);
                else
                    self.log.throw_error("Invalid Transducer ID %s. Valid IDs are [%s]", trans.id, join(trans_ids,', '));
                end
            end
            filename = self.get_connected_transducer_filename();
            fid = fopen(filename, 'w');
            fwrite(fid, trans.id);
            fclose(fid);
        end
        
    end
    
    methods (Access=protected)
        
        function connected_system_filename = get_connected_system_filename(self)
            arguments
                self fus.Database
            end
            connected_system_filename = fullfile(self.path, "systems", "connected_system.txt");
        end
        
        function connected_transducer_filename = get_connected_transducer_filename(self)
            arguments
                self fus.Database
            end
            connected_transducer_filename = fullfile(self.path, 'transducers', 'connected_transducer.txt');
        end
        
        function plans_filename = get_plans_filename(self)
            arguments 
                self fus.Database
            end
            plans_filename = fullfile(self.path, 'plans', 'plans.json');
        end
        
        function plan_filename = get_plan_filename(self, plan_id)
            arguments
                self fus.Database
                plan_id (1,1) string {mustBeValidVariableName}
            end
            plan_filename = fullfile(self.path, 'plans', plan_id, sprintf('%s.json', plan_id));
        end
        
        function session_dir = get_session_dir(self, subject_id, session_id)
            arguments
                self fus.Database
                subject_id (1,1) string {mustBeValidVariableName}
                session_id (1,1) string {mustBeValidVariableName}
            end
            session_dir = fullfile(self.get_subject_dir(subject_id), 'sessions', session_id);
        end
        
        function session_filename = get_session_filename(self, subject_id, session_id)
            arguments
                self fus.Database
                subject_id (1,1) string {mustBeValidVariableName}
                session_id (1,1) string {mustBeValidVariableName}
            end
            session_filename = fullfile(self.get_session_dir(subject_id, session_id), sprintf('%s.json', session_id));
        end
        
        function sessions_filename = get_sessions_filename(self, subject_id)
            arguments
                self fus.Database
                subject_id (1,1) string {mustBeValidVariableName}
            end
            sessions_filename = fullfile(self.get_subject_dir(subject_id), 'sessions', 'sessions.json');
        end
        
        function solution_filename = get_solution_filename(self, subject_id, session_id, plan_id, target_id, ext)
            arguments
                self fus.Database
                subject_id (1,1) string {mustBeValidVariableName}
                session_id (1,1) string {mustBeValidVariableName}
                plan_id (1,1) string {mustBeValidVariableName}
                target_id (1,1) string {mustBeValidVariableName}
                ext (1,1) string {mustBeMember(ext, ["mat", "json", "analysis.json"])} = "mat"
            end
            session_dir = get_session_dir(self, subject_id, session_id);
            solution_filename = fullfile(session_dir, 'solutions', plan_id, sprintf("%s.%s", target_id, ext));
        end 
        
        function solutions_filename = get_solutions_filename(self, subject_id, session_id)
            arguments
                self fus.Database
                subject_id (1,1) string {mustBeValidVariableName}
                session_id (1,1) string {mustBeValidVariableName}
            end
            session_dir = get_session_dir(self, subject_id, session_id);
            solutions_filename = fullfile(session_dir, 'solutions', 'solutions.json');
        end

        function standoff_filename = get_standoff_filename(self, transducer_id, standoff_id)
            arguments
                self fus.Database
                transducer_id (1,1) string {mustBeValidVariableName}
                standoff_id (1,1) string {mustBeValidVariableName} = "standoff"
            end
            standoff_filename = fullfile(self.path, 'transducers', transducer_id, sprintf('%s.json', standoff_id));
        end
        
        function subject_dir = get_subject_dir(self, subject_id)
            arguments
                self fus.Database
                subject_id (1,1) string {mustBeValidVariableName}
            end
            subject_dir = fullfile(self.path, 'subjects', subject_id);
        end
        
        function subject_filename = get_subject_filename(self, subject_id)
            arguments
                self fus.Database
                subject_id (1,1) string {mustBeValidVariableName}
            end
            subject_dir = self.get_subject_dir(subject_id);
            subject_filename = fullfile(subject_dir, sprintf('%s.json', subject_id));
        end
        
        function subjects_filename = get_subjects_filename(self)
            arguments
                self fus.Database
            end
            subjects_filename = fullfile(self.path, 'subjects', 'subjects.json');
        end
        
        function systems_filename = get_systems_filename(self)
            arguments
                self fus.Database
            end
            systems_filename = fullfile(self.path, 'systems', 'systems.json');
        end
        
        function system_filename = get_system_filename(self, system_id)
            arguments
                self fus.Database
                system_id (1,1) string {mustBeValidVariableName}
            end
            system_filename = fullfile(self.path, 'systems', system_id, sprintf("%s.json", system_id));
        end
        
        function transducer_filename = get_transducer_filename(self, transducer_id)
            arguments
                self fus.Database
                transducer_id (1,1) string {mustBeValidVariableName}
            end
            transducer_filename = fullfile(self.path, 'transducers', transducer_id, sprintf('%s.json', transducer_id));
        end
        
        function transducers_filename = get_transducers_filename(self)
            arguments
                self fus.Database
            end
            trans_path = fullfile(self.path, 'transducers');
            transducers_filename = fullfile(trans_path, 'transducers.json');
        end    
        
        function volume_filename = get_volume_filename(self, subject_id, volume_id, options)
            arguments
                self fus.Database
                subject_id (1,1) string {mustBeValidVariableName}
                volume_id (1,1) string {mustBeValidVariableName}
                options.ext (1,1) string {mustBeMember(options.ext, ["nii","mat","json"])} = "nii"
            end
            subject_dir = self.get_subject_dir(subject_id);
            volume_filename = fullfile(subject_dir, 'volumes', sprintf('%s.%s', volume_id, options.ext));
        end
        
        function write_plan_ids(self, plan_ids)
            arguments
                self fus.Database
                plan_ids (1,:) string {mustBeValidVariableName}
            end
            plan_data = struct('plan_ids', plan_ids);
            plans_filename = self.get_plans_filename();
            fus.util.struct2json(plan_data, plans_filename);
        end
        
        function write_session_ids(self, subject_id, session_ids)
            arguments
                self fus.Database
                subject_id (1,1) string {mustBeValidVariableName}
                session_ids (1,:) string {mustBeValidVariableName}
            end
            session_data = struct('session_ids', session_ids);
            sessions_filename = self.get_sessions_filename(subject_id);
            fus.util.struct2json(session_data, sessions_filename);
        end
        
        function write_subject_ids(self, subject_ids)
            arguments
                self fus.Database
                subject_ids (1,:) string {mustBeValidVariableName}
            end
            subject_data = struct('subject_ids', subject_ids);
            subjects_filename = self.get_subjects_filename();
            fus.util.struct2json(subject_data, subjects_filename);
        end
        
        function write_transducer_ids(self, transducer_ids)
            arguments
                self fus.Database
                transducer_ids (1,:) string {mustBeValidVariableName}
            end
            transducers_data = struct('transducer_ids', transducer_ids);
            transducers_filename = self.get_transducers_filename();
            fus.util.struct2json(transducers_data, transducers_filename);
        end
        
    end
    
    methods (Static)      
        function user_dir = get_default_user_dir()
            user_dir = fileparts(winqueryreg(...
                "HKEY_CURRENT_USER", ...
                "Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders",...
                "Personal"));
        end
        
        function db_path = get_default_path(options)
            arguments
                options.figure = -1
                options.default_location (1,1) string = "."
                options.save (1,1) logical = true
                options.log fus.util.Logger = fus.util.Logger.get()
            end
            log = options.log;
            paths = fus.get_paths();
            if isfield(paths, 'db')
                db_path = paths.db;
            else
                path_ok = false;
                log.warning('Database directory not found on disk. Please identify the location of the database')
                answer = fus.util.dlg_confirm(...
                    'Please identify the location of the database', ...
                    'Select Database', ...
                    'Options', {'Choose...', 'Exit'}, ...
                    'DefaultOption', 1, ...
                    'CancelOption', 2, ...
                    'Icon', 'warning', ...
                    'figure', options.figure);
                switch answer
                    case 'Choose...'
                        choosepath = uigetdir(options.default_location, 'Select location of database');
                        choosepath = strrep(choosepath, '\', '/');
                        if ~isnumeric(choosepath) && isfolder(choosepath)
                            db_path = choosepath;
                            paths.db = db_path;
                            if options.save
                                fus.save_paths(paths);
                            end
                            path_ok = true;
                        end
                    case 'Exit'
                end
                if ~path_ok
                    db_path = string.empty;
                    log.error('Could not find Database');
                    fus.util.dlg_alert(...
                        'Could not find Database',...
                        'Invalid Path', ...
                        'Icon', 'error', ...
                        'figure', options.figure);
                end
            end
        end
    end
end