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
scene = session.to_scene(id="raw", name="Raw Scene");    
%% Create Treatment Plan
% We'll load the plan from disk, and then replace its focal_pattern with a
% another object of FocalPattern class - in this case, a Wheel
% object. The Wheel has additional properties to specify its
% geometry. Additional custom classes can be added to the +pattern folder,
% as long as they at least implement the `get_targets` and `num_foci`
% methods that are required of the Abstract class fus.bf.FocalPattern.
plan = db.load_plan("example_plan");
plan.id = "modified_plan";
plan.name = "Four Foci";
plan.sequence.pulse_count = 12;
plan.focal_pattern = fus.bf.focalpatterns.Wheel(...
    "target_pressure", 1e6, ...
    "center", false, ...
    "spoke_radius", 12, ...
    "num_spokes", 4, ...
    "units", "mm");
db.add_plan(plan, "on_conflict", "overwrite");
sim_scene = plan.transform_sim_scene(scene);
%% Modify the simulation space
% We can also use some of the tools in the toolbox to manually assign new
% material parameters for the simulation space.
% First, we'll pull out the attenuation volume from the scene:
attenuation = sim_scene.volumes.by_id("attenuation")
% Next, we'll convert the coordinates into an ND-grid. We'll also use the
% transformation matrix from the original session to get those coordinates
% back in the original LPS coordinates.
matrix = session.transducer.get_matrix("units", "m");
xyz = attenuation.coords.ndgrid(); % ND grid relative to transducer
lps = attenuation.coords.ndgrid("matrix", matrix) % relative to LPS
% lps{3} is the "S" coordinate, so we can mask our attenuation map by
% wherever S is above the midline and we are more than 30 mm from the 
% transducer face and give it nonzero attenuation there
mask = ((lps{3}>0) & (xyz{3}>30e-3));
attenuation.data(mask) = 5;
attenuation.data(~mask) = 0.02;
% We DO NOT need at assign the `attenuation` object back into the scene
% volumes. Becaues volumes passed by reference, we've directly acted on the
% object in the scene.
figure(1);clf
sim_scene.volumes.by_id("attenuation").slice(0,0,0);
%% Generate Solution
% Now we can beamform and simulate the treatment plan. In this case, we'll
% initially set scale_solution to false, so that the plan does not scale up
% the signals to match the target pressures.
[solution, output] = plan.calc_solution(sim_scene, on_pulse_mismatch="rounddown",  scale_solution=false);
%% Visualize Results
% We can slice our results to the focal depth (ax=50e-3), and draw images
% for each focus.
figure(2);clf
subplot(3,2,[1,2])
colormap(gca, "parula")
attenuation.sel('ax',50e-3).imagesc();
for i = 1:solution.num_foci
    subplot(3,2,i+2)
    colormap(gca,"turbo")
    output.pnp(i).sel('ax',50e-3).imagesc([0, 0.4e6]);   
end
%% Visualize the Simulation output
% This time, we'll auto-generate the mri colormap, but still manually
% generate the PNP map
mapper_mri = fus.ColorMapper.from_volume(sim_scene.volumes(1), cmap="bone");
mapper_pmax = fus.ColorMapper(...
    cmap=jet(256), ...
    clim_in=[0 1e6], ...
    alim_in=[1e5, 4e5], ...
    alim_out=[0, 0.6]);
% We are not limited to two volume objects/colormaps - we can stack as many
% as want and they will all become layered togeter, so we can make 
tmp = output.pnp.copy();
%for i = 1:length(tmp)
%    tmp(i).data = tmp(i).data.*fus.bf.mask_focus(output_initial.get_coords, solution_initial.focus(i), 2, "units", "mm", "aspect_ratio", [1, 1, 5]);
%end
vols_initial = [sim_scene.volumes(1), tmp];
mappers = [mapper_mri repmat(mapper_pmax,1,solution.num_foci)];
figure(3);clf
slices = {0,-1e-3,[0 50e-3]};
for i = 1:length(vols_initial.dims)
    dim = vols_initial.dims(i);
    vols_initial.sel(dim, slices{i}).draw_surface(mappers, colorbar_index=2);
    hold on
end
set(gca,'color',[0.1, 0.2, 0.3])
axis image
%% Scale the solutions and output
% The scale_solution method looks at the peak negative pressure in the
% field, and computes how the signal amplitude needs to scale up over the
% nominal value used in the simulation in order to reach the target
% pressure. The same pulse amplitude (i.e. voltage) is used for all foci, 
% with per-focus apodization scaling used to provide variable signal 
% amplitude across foci.
[solution_scaled, output_scaled] = plan.scale_solution(solution, output);
%% Visualize the Balanced Output
vols = [sim_scene.volumes(1), output_scaled.pnp];
figure(4);clf
slices = {0,0,[0 50e-3]};
for i = 1:length(vols.dims)
    dim = vols.dims(i);
    vols.sel(dim, slices{i}).draw_surface(mappers, colorbar_index=2);
    hold on
end
set(gca,'color',[0.1, 0.2, 0.3])
axis image
