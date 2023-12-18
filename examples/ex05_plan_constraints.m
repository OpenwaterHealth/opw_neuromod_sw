%% Make sure that fus is on MATLAB's search path.
addpath(fileparts(fileparts(mfilename('fullpath'))))
if isempty(which('fus.Database'))
    error('fus needs to be added to the path. Run this example as a script or add it manually to continue');
end
%% Load the same database we used in the first example
user_dir = fus.Database.get_default_user_dir();
db_path = fullfile(user_dir, "Documents", "db");
db = fus.Database(path=db_path);
%% Load the Scene
subject_id = 'example_subject';
subject = db.load_subject(subject_id);
session_id = 'example_session';
session = db.load_session(subject, session_id);
scene = session.to_scene(id="base", name="Base Scene");    
%% Create Treatment Plan
plan = db.load_plan("example_plan");
plan.id = "test_target_constraints";
plan.name = "Target Constraint Test";
% We now add a TargetConstraint to the treatment plan, to restrict the
% steering available to this plan.
plan.target_constraints(1) = fus.treatment.TargetConstraint(...
    "dim", "ax", ...
    "name", "Axial", ...
    "max", 48, ...
    "units", "mm");
plan.target_constraints(2) = fus.treatment.TargetConstraint(...
    "dim", "lat", ...
    "name", "Lateral", ...
    "min", 20, ...
    "max", 20, ...
    "units", "mm");
sim_scene = plan.transform_sim_scene(scene);
target = sim_scene.targets(1);
% We can use TreatmentPlan.check_targets to evaluate the position of the
% target against the plan constraints. The result is a structure:
disp(plan.check_targets(target))
%% Try to calculate solution
% At the same time, if we attempt to calculate a solution for this target, 
% we'll get an error, because the same check is run internally:
[solution, output] = plan.calc_solution(sim_scene);
%%
[solution, output]  = db.load_solution(session, "modified_plan", "example_target");
%% Switch to Param Constraints
plan.target_constraints(:) = [];
plan.param_constraints(1) = fus.treatment.ParameterConstraint(...
    "id", "MI", ...
    "name", "MI", ...
    "warn_func", @(MI)MI>1.0);
plan.check_analysis(output.analysis)
%%
[solution, output] = plan.calc_solution(sim_scene);
