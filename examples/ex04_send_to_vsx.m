user_dir = fus.Database.get_default_user_dir();
db_path = fullfile(user_dir, "Documents", "db");
db = fus.Database(path=db_path);
subject_id = "example_subject";
session_id = "example_session";
plan_id = "example_plan";
target_id = "example_target";
subject = db.load_subject(subject_id);
session = db.load_session(subject, session_id);
solution = db.load_solution(session, plan_id, target_id);
config = fus.sys.verasonics.setup(solution, "log", db.log);
fus.sys.verasonics.run(config, "simulate", true)