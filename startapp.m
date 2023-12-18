function app = startapp(options)
    % STARTAPP Start the FUS planning app
    arguments
        options.path (1,1) string {mustBeFolder} = fus.Database.get_default_path
        options.subject_id (1,1) string {mustBeValidVariableName}
        options.session_id (1,1) string {mustBeValidVariableName}
        options.plan_ids (1,:) string {mustBeValidVariableName}
        options.logoptions struct
        options.log fus.util.Logger
        options.uiwait = false
    end
    if isfield(options, "logoptions")
        logargs = fus.util.struct2args(options.logoptions);
        options = rmfield(options, "logoptions");
        options.log = fus.util.Logger(logargs{:});
    elseif ~isfield(options, "log")
        options.log = fus.util.Logger.get();
    end
    args = fus.util.struct2args(rmfield(options, "uiwait"));
    options.log.info("Starting Application...")
    app = fus.ui.FUSPlan(args{:});
    options.log.info("Started Application");
    if options.uiwait
        uiwait(app.UIFigure);
    end
    options.log.info("Exited Application")
    options.log.close()
end