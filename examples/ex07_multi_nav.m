%% Load the Scene and swap in our target transducer
user_dir = fus.Database.get_default_user_dir();
db_path = fullfile(user_dir, "Documents", "db");
db = fus.Database(path=db_path);
subject_id = 'example_subject';
subject = db.load_subject(subject_id);
session_id = 'example_session';
session = db.load_session(subject, session_id);
scene_orig = session.to_scene(id="base", name="Base Scene"); 
transducer = fus.xdc.Transducer.gen_matrix_array(...
    "id", "matrix_256_01",...
    "name", "256 Element Matrix (01)", ...
    "nx", 16, ... number of lateral elements
    "ny", 16, ... number of elevation elements
    "pitch", 2, ... element pitch
    "kerf", 0.1, ... spacing metween elements
    "impulse_response", 1e6/10, ... % element impulse response (Pa/V): 10V = 1MPa
    "matrix", scene_orig.transducer.matrix, ... % copy the position from the matrix in the scene
    "units", "mm"... spatial scaling
    ); %
scene_orig.transducer = transducer;
%% Position the transducers interactively
f = uifigure("Position", [100, 50, 1000, 1200]);
g = uigridlayout(f, ...
    [4, 1], ...
    "RowHeight", {"3x", "2x", 40});
tw = fus.xdc.TransWidget.from_scene(scene_orig, ...
    "fourup_parent", g, ...
    "parent", g, ...
    "tabs", "orbit");
tw.UserData.index = 1;
tw.UserData.transducers = tw.trans;
tw.UserData.thandles = tw.trans_handle;
g1 = uigridlayout(g, [1, 4], "Padding", [0,0,0,0]);
tw.UserData.add_transducer_button = uibutton(g1, ...
    "Text", "Copy Transducer", ...
    "FontSize", 20, "FontWeight", "bold", ...
    "ButtonPushedFcn", {@add_transducer,tw});
tw.UserData.rm_transducer_button = uibutton(g1, ...
    "Text", "Remove Transducer", ...
    "Enable", "off", ...
    "FontSize", 20, "FontWeight", "bold", ...
    "ButtonPushedFcn", {@rm_transducer,tw});
tw.UserData.set_index_dropdown = uidropdown(g1,...
    "Items", [transducer.name], ...
    "ItemsData", 1:length(transducer), ...
    "FontSize", 20, "FontWeight", "bold", ...
    "ValueChangedFcn", {@set_index, tw});
tw.UserData.show_matrix_button = uibutton(g1, ...
    "Text", "Show Matrices", ...
    "FontSize", 20, "FontWeight", "bold", ...
    "ButtonPushedFcn", {@show_matrices,tw});
%%
keyboard
%% Merge the transducers into a scene copy
merged_transducer = tw.UserData.transducers.merge("reference", "average");
scene = scene_orig.copy();
scene.targets(1).position = [0;0;0];
scene.targets(1).radius = 5;
scene.transducer = merged_transducer;
% Load the Treatment Plan
plan = db.load_plan("example_plan");
% Edit the simulation grid size to account for the multiple transducers
corners = merged_transducer.get_corners("transform", false);
exmin = round(cellfun(@(x)min(x,[],'all'),corners) + [-2, -2, -5]);
exmax = round(cellfun(@(x)max(x,[],'all'),corners) + [2, 2, 0]);
local_target_pos = inv(scene.transducer.matrix)*[scene.targets.position;1];
exmax(3) = round(local_target_pos(3) + 10);
plan.sim_setup.x_extent = [exmin(1), exmax(1)];
plan.sim_setup.y_extent = [exmin(2), exmax(2)];
plan.sim_setup.z_extent = [exmin(3), exmax(3)];
sim_scene = plan.transform_sim_scene(scene);
% Store the arguments for fus.ui.FourUp (used later) so that we can re-use them
fprops = struct(...
    "colorbar", true, ...
    "axes_props", struct("color", "k"), ...
    "fig_props", struct("Position", [100, 100, 1500, 1000]));
fargs = fus.util.struct2args(fprops);
sim_scene.four_up("volume_ids", sim_scene.volumes(1).id, fargs{:});
%% Beamform and Simulate
solution = plan.calc_solution(sim_scene);
out_scenes = solution.to_scenes(sim_scene);
out_base = solution.to_scenes(scene);
%% Show Results
f1 = out_scenes(1).four_up(fargs{:});
f2 = out_base(1).four_up(fargs{:});


%%
function add_transducer(src, eventdata,tw)
    index = tw.UserData.index;
    transducers = tw.UserData.transducers;
    new_index = length(transducers)+1;
    thandles = tw.UserData.thandles;
    new_trans = transducers(index).copy();
    new_trans.id = sprintf('%s_%02d', new_trans.id{1}(1:end-3), new_index);
    new_trans.name = sprintf('%s (%02d)', new_trans.name{1}(1:end-5), new_index);
    transducers = [transducers new_trans];
    thandles = [thandles copyobj(thandles(index), ancestor(thandles(index), "axes"))];
    set(tw.UserData.set_index_dropdown, ...
        "Items", [transducers.name], ...
        "ItemsData", 1:length(transducers));
    tw.UserData.transducers = transducers;
    tw.UserData.thandles = thandles;
    tw.UserData.rm_transducer_button.Enable = "on";
    set_index(struct('Value',new_index),[],tw);
end
function rm_transducer(src, eventdata, tw)
    index = tw.UserData.index;
    transducers = tw.UserData.transducers;
    thandles = tw.UserData.thandles;
    transducers(index) = [];
    delete(thandles(index));
    thandles(index) = [];
    if numel(transducers) == 1
        set(tw.UserData.rm_transducer_button, "Enable", "off");
    end
    new_index = min(length(transducers), index);
    tw.UserData.transducers = transducers;
    tw.UserData.thandles = thandles;
    set(tw.UserData.set_index_dropdown, ...
        "Items", [transducers.name], ...
        "ItemsData", 1:length(transducers), ...
        "Value", new_index);
    set_index(struct('Value',new_index),[],tw);
end

function set_index(src, eventdata, tw)
    index = src.Value;
    tw.UserData.set_index_dropdown.Value = index;
    tw.trans = tw.UserData.transducers(index);
    tw.trans_handle = tw.UserData.thandles(index);
    tw.UserData.index = index;
    for i = 1:length(tw.UserData.transducers)
        trans = tw.UserData.transducers(i);
        trans.id = sprintf('%s_%02d', trans.id{1}(1:end-3), i);
        trans.name = sprintf('%s (%02d)', trans.name{1}(1:end-5), i);
        th = tw.UserData.thandles(i);
        if i == index
            set(th, "EdgeColor","c","FaceColor","g");
        else
            set(th, "EdgeColor","b","FaceColor","c");
        end
    end
    tw.UserData.set_index_dropdown.Items = [tw.UserData.transducers.name];
end

function show_matrices(src, eventdata, tw)
    transducers = tw.UserData.transducers;
    fprintf("m = cell(1,%d);\n", numel(transducers))
    for i = 1:numel(transducers)
        trans = transducers(i);
        fprintf("m{%d} = [... %s (%s)", i, trans.name, trans.id);
        for j = 1:4
            fprintf("\n        %g, %g, %g, %g;...", trans.matrix(j,:));
        end
        fprintf("\b\b\b\b];\n");
    end 
end

