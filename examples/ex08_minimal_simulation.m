db = fus.Database();
trans = db.load_transducer("vermon2");
plan = db.load_plan("example_plan");
target = fus.Point("position", [0, 0, 50]);
sim_scene = plan.gen_reference_sim_scene(trans, target);
[solution, output] = plan.calc_solution(sim_scene);
out_scenes = solution.to_scenes(output, sim_scene);
f = out_scenes.by_id("pnp").four_up();
