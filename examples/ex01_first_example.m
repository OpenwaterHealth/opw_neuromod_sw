% FIRST EXAMPLE
% This code walks through the data and filesystem creation and the basics
% of a number of the dataclasses included in open-LIFU.
%%
% First we'll make sure that fus is on MATLAB's search path.
addpath(fileparts(fileparts(mfilename('fullpath'))))
if isempty(which('fus.Database'))
    error('fus needs to be added to the path. Run this example as a script or add it manually to continue');
end
%% Get the location of the database. Default to C:/Users/<username>/Documents/db
user_dir = fus.Database.get_default_user_dir();
db_path = fullfile(user_dir, "Documents", "db");
if ~isfolder(db_path)
    mkdir(db_path);
end
db = fus.Database(path=db_path);
%% Create a Subject
% First we will create an example Subject. The subject will not have any
% sessions associated with it or volumes attached to it. The subject is a
% construct of the database's storage model to help organize data
% efficiently, because once volumes are attached, they can be re-used for
% multiple sessions.
subject_id = "example_subject";
subject = fus.Subject(id=subject_id, name="Example Subject");
% add the subject to the database
db.add_subject(subject, on_conflict="overwrite");
%% Download Example Data
% To create a volume, we'll get the example MNI dataset. We'll put it in an
% "downloaded_example_data" folder
example_data_path = fullfile(db_path, "downloaded_example_data");
if ~isfolder(example_data_path)
    mkdir(example_data_path);
end
example_filename = fullfile(example_data_path, "average305_t1_tal_lin.nii");
if isfile(example_filename)
    db.log.info("Example data found!")
else
    example_zip = fullfile(example_data_path, "mni.nii.zip");
    url = 'https://packages.bic.mni.mcgill.ca/mni-models/mni305/mni305_lin_nifti.zip';
    db.log.info("Downloading example data from %s", url)
    outname = websave(example_zip, url);
    db.log.info("Downloaded to %s", outname);
    unzip(outname,  example_data_path);
end
%% Load the volume from file
% By default, the NIFTI file puts the origin in the corner of the Volume,
% and uses RAS coordinates, but we'd like to use LPS coordinates which are 
% centered, so we'll tell the volume how it is oriented and perform a
% simple transformation to get it into standard coordinates;
vol0 = fus.Volume.from_nifti(example_filename, 'id', 'mni', 'name', 'MNI');
origin = cellfun(@mean, {vol0.coords.values});
matrix = [-1 0 0 origin(1); 0 -1 0 origin(2); 0 0 1 -origin(3); 0 0 0 1];
vol0.matrix = matrix;
x = vol0.coords(1).values;
ax_L = fus.Axis((x-mean(x)), "L", units="mm");
y = vol0.coords(2).values;
ax_P = fus.Axis((y-mean(y)), "P", units="mm");
z = vol0.coords(3).values;
ax_S = fus.Axis((z-mean(z)), "S", units="mm");
vol = vol0.transform([ax_L, ax_P, ax_S], eye(4));
%% Visualize LPS Volume
% Volume objects have a number of options for visualizing them. The slice
% method is a simple one that takes arrays of values for each of the three
% dimensions of the volume, and slices the array in those dimensions by
% those values
figure(1);clf
vol.slice(0,0,0, "cmap", "bone");
%% Add Volume to database
% Add the volume to the subject. This is optional, as the code will check
% for the volume to be indexed by the subject when adding it to the
% database and add it at that time, but we can also attach volumes directly
% to subjects without any session data
db.add_volume(subject, vol, on_conflict="overwrite");
db.log.info('Volumes: %s', strip(formattedDisplayText(subject.volumes)))
%% Load the Subject
% Because the subject is referenced by pointer, the volume will already be
% attached by the db.add_volume command. However, we can confirm that the
% subject was formed and saved correctly by loading it from disk.
subject = db.load_subject(subject_id);
%% Create a Session
% A Session is class that hold information about a volume, targets,
% reference points, and a transducer. These data define treatment targets
% and the orientation of the transducer releative to the volume.
session_id = "example_session";
% Create a target
target = fus.Point(id="example_target", name="Example Target", position=[0;-50;0], dims=["L","P","S"]);
% Create a simple matrix array transducer. We'll position it a little bit
% above the centerline, and pointed slightly down by specifying it's
% transformation matrix
trans_matrix = [...
    -1,   0,  0, 0;...
     0, .05,  sqrt(1-.05^2), -105;...
     0, sqrt(1-.05^2),  -.05, 5;...
     0, 0,  0, 1];
transducer = fus.xdc.Transducer.gen_matrix_array(...
    id="example_transducer",...
    name="Example Transducer", ...
    nx=8, ... number of lateral elements
    ny=8, ... number of elevation elements
    pitch=4, ... element pitch
    kerf=0.5, ... spacing metween elements
    matrix=trans_matrix, ... % transformation matrix specifying transducer position/orientation
    impulse_response=1e6/10, ... % element impulse response (Pa/V): 10V = 1MPa
    units="mm"... spatial scaling
    ); %
% Create the Session
session = fus.Session(...
    id=session_id, ...
    name="Example Session", ...
    volume=vol, ...
    targets=[target], ...
    transducer=transducer);
% Add it to the database. If the transducer or volume are not found in the
% database, they will be added
db.add_session(subject, session, on_conflict="overwrite");
% But we can manually add the transducer as well
db.add_transducer(transducer, on_conflict="overwrite");
%% Load Session
% Again, we already have it in memory, but we can load the session to
% verify that it looks right
session = db.load_session(subject, session_id);
%% Visualize Session Data
% We'll now cover some of the visualization options for these object
% classes. 
figure(2);clf
% a ColorMapper object holds a colormap and a set of values that map scalar
% data values to colors and transparencies. A mapper is a reusable way to
% adjust the display of data across different visualizations. 
mapper = fus.ColorMapper(...
    cmap=turbo(128),... the raw colormap
    clim_in=[20, 160], ... the colormap limits: <20=blue, >160=red
    alim_in=[15, 30], ... the alpha limits: <15=min opacity, >30=max opactity
    alim_out=[0, 0.9]... the alpha output: min opacity=0%, max opacity=90%
    );
for dim = session.volume.dims % Iterate over the dimensions
    vx = session.volume.sel(dim, mean(session.volume.coords.by_id(dim).values)+[-20 20]); %Slice along a dimension
    vx.draw_surface(mapper, "transform", true); % Draw a surface in 3D according to the mapper. 
    hold all
end
set(gca,'color',[0.6 0.6 0.6])
axis image
h = session.targets.draw(scale=3); % Draw the target as a sphere
% Now we'll draw the transducer
session.transducer.draw(); % Draws elements as patches
legend(h, "Location", "NorthEast")
%% Display Database
% Finally, we will recursively display the contents of the database
db.log.info(db.list_files)