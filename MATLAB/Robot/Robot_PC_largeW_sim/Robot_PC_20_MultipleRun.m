
cla
close all;
clc;

%% Variable Setup

addpath('C:\Users\IceFox\Desktop\ERMINE\MATLAB\Robot_PC')
addpath('C:\Users\IceFox\Desktop\ERMINE\MATLAB\Robot_PC\Maps')

% General Map Setup
file_map = 'Empty';   % Set Map as 'Empty' for empty map
grid_size = [8 8];   % Assign values for grid size if an empty map is chosen
grid_w = 25;    % Grid width (unit:cm)

tol_wp = 6; %18    % Waypoint tolerance (unit:cm)               
tol_line_width =  10; %12;    % Route deviation tolerance (unit:cm)

cvg_sample_side = [20 20];  % Robot map coverage samples size 
fixed_offset = [96.5 -54.5];    % Initial robot position offset (unit:cm)

% Grid Map Setup
starting_grid = [1 2];  % Robot starting grid
clims = [-1000, 200];  % Grid color map limits
grid_coverage_grid_default_value = -980;
grid_coverage_colormap = 'parula'; % Colormap format
grid_coverage_sim_increase = 8; % Grid color map value increased for each step during simulation;
grid_coverage_increase = 1; % Grid color map value increased for each step during robot demo;

% Algorithms
navigation_mode = 'MultipleRun';
zigzag_mode = 'simple';

% Time Frame Setup
max_step = 20000;   % Maximum system steps
interval_system_time =2;   % Robot dynamics update intervals
interval_normal_linear_command_send = 15; % Robot normal linear commands sending interval
interval_rotation_command_send = 10;    % Robot rotation commands sending interval

% Robot Dynamics Setup
robot_Form = 24; % Robot starting shape
heading = [0 pi pi*3/2 pi/2];
tol_transform = pi/50;  % Robot Transformation angle tolerance (unit:rad)
Dy_angv_transform = pi/48;  % Robot transformation angular velocity (unit:rad)
tol_heading = pi/7; % Robot heading deviation tolerance (unit:rad)

update_rate_streaming = 1;  % Robot position update rate during data streaming
update_rate_streaming_single_value = 1; % Robot position update rate during data streaming with single values
update_rate_sim = 0.2; % Robot position update rate during simulation

% Serial Communication Setup
Serial_port = 'COM12';  % Communication port to XBee module
baudrate = 9600;    % default:9600


% Toggle 
is_xbee_on = false; 
is_streaming_on = false;

is_calculate_coverage = true;
is_calculate_grid_coverage_duration = true;
is_display_coverage_map = true;
is_display_wp = true;   
is_display_wp_clearing = false;
is_display_route = true;
is_display_route_clearing = true;
is_display_grid_on = true;
is_display_obstacle = true;
is_display_grid_coverage_map = false;
is_display_ignite_swept_grid = true;
is_print_coverage = false;
is_print_sent_commands = false;
is_print_route_deviation = false;
is_fixed_offset = false;
is_sim_normal_noise_on= false;
is_sim_large_noise_y_on = false;
is_sim_heading_correction = false;
is_streaming_collect_single_values = true;

% Data streaming setup
streaming_max_single_val = 1000;                 % Accepted maximum streaming value from data log. (unit: cm)
streaming_max_shift_dis = 35;                       % Accepted maximum shifting distance between two positions. (unit: cm)
streaming_max_shift_dis_single_value = 30;    % Accepted maximum shifting distance between two positions during single value streaming (unit: cm)

max_pos_initialize = 10;    % Number of valid position values required to finish robot initialization

% Simulation Setup
sim_noise_normal = 20;  % Noise value during simulation (unit: cm)
sim_noise_large_y_frequency = 0.05; % Frequency of large Y axis noise during simulation 
sim_noise_large_y = 50; % large Y axis noise value during simulation (unit: cm)

robot_weight = [1.5 1.5 1.5 1.5]; % Robot weights (unit: kg)


%% Variable initialization

is_using_obs_map = false;

Map_obs = [];
if exist([file_map, '.txt'], 'file') == 2
    Map_obs = csvread([file_map, '.txt']);
    disp(['Map: ', file_map, '.txt loaded successfully!']);
    grid_size = Map_obs(1,:);
    is_using_obs_map = true;
else
    disp(['Default map loaded successfully!']);
end


RobotShapes = [0 0 0 0 ;              
                        0 0 pi pi;
                        -pi 0 pi/2 -pi/2;
                        -pi 0 0 0;
                        -pi 0 0 -pi;
                        -pi/2 0 pi 0;
                        -pi/2 0 pi pi/2];


time_pause = interval_system_time/700;

pos_uwb_offset = [12.5 37.5];

    %                                    Robot Shapes
    %   =====================================
    %         s01     s02      s03     s04      s05        s06       s07
    %   -----------------------------------------------------------------
    %
    %          4                  4         4
    %          3       2 3       3         3       4 3        2 3 4           3 4
    %          2       1 4       2 1    1 2          2 1        1          2 1 
    %          1                      
    %
    %         s08           s010         s11        s12       s13      s14
    %   -----------------------------------------------------------------
    %
    %                        1 2 4        1              4         2            2
    %       1 2 3 4            3         2 3 4      2 3      1 3         1 3
    %                                                     1           4         4
    %  

    Robot_Relative_Pos = [0 -1; 0 1; 0 2;
                                     0 -1; 1 0; 1 -1;
                                     -1 0; 0 1; 1 1;
                                     -1 0; 0 1; 0 2;
                                     1 0; 0 1; -1 1;
                                     1 -1; 1 0; 2 0;
                                     1 -1; 1 0; 2 -1];



    Char_command_array_linear = ['R', 'F', 'L', 'B'];
    Char_command_array_linear_adjustment =  ['r', 'f', 'l', 'b'];



%% Waypoint Generation
Wp_series = [];
if (strcmp(navigation_mode,'MultipleRun'))
    disp('Generating waypoints...')
    [num_runs, Wp_series] = MultipleRunImport('asd',grid_w);
    
else
    disp('Navigation method is invalid.')
    disp('Terminating Matlab script...')
    return
end


for run = 8
    
    clf
    robot_Form = 24; % Robot starting shape
    heading = [0 pi pi*3/2 pi/2];
    Wp = [Wp_series(run,:,1); Wp_series(run,:,2); Wp_series(run,:,3)].';
    pos_uwb_offset = Wp(1, 1:2);
    wp_current = 1;
    distance_travelled = 0;
    count_J_rot_clockwise = 0;
    count_J_rot_counterclockwise = 0;
    count_J_rot_180deg = 0;
    
    count_L_rot_clockwise = 0;
    count_L_rot_counterclockwise = 0;
    count_L_rot_180deg = 0;
    
    count_T_rot_clockwise = 0;
    count_T_rot_counterclockwise = 0;
    count_T_rot_180deg = 0;
    
    count_Z_rot_clockwise = 0;
    count_Z_rot_counterclockwise = 0;
    count_Z_rot_180deg = 0;
    
    count_S_rot_clockwise = 0;
    count_S_rot_counterclockwise = 0;
    count_S_rot_180deg = 0;
    
    count_O_rot_clockwise = 0;
    count_O_rot_counterclockwise = 0;
    count_O_rot_180deg = 0;
    
    count_JtoL_tf = 0;
    count_JtoT_tf = 0;
    count_JtoZ_tf = 0;
    count_JtoS_tf = 0;
    count_JtoO_tf = 0;
    
    
    count_LtoJ_tf = 0;
    count_LtoT_tf = 0;
    count_LtoZ_tf = 0;
    count_LtoS_tf = 0;
    count_LtoO_tf = 0;
    
    count_TtoL_tf = 0;
    count_TtoJ_tf = 0;
    count_TtoZ_tf = 0;
    count_TtoS_tf = 0;
    count_TtoO_tf = 0;

    count_ZtoL_tf = 0;
    count_ZtoJ_tf = 0;
    count_ZtoT_tf = 0;
    count_ZtoS_tf = 0;
    count_ZtoO_tf = 0;
    
    count_StoL_tf = 0;
    count_StoJ_tf = 0;
    count_StoZ_tf = 0;
    count_StoT_tf = 0;
    count_StoO_tf = 0;
    
    count_OtoL_tf = 0;
    count_OtoJ_tf = 0;
    count_OtoZ_tf = 0;
    count_OtoT_tf = 0;
    count_OtoS_tf = 0;   
    
    J_F_distance = 0;
    J_R_distance = 0;
    J_L_distance = 0;
    J_B_distance = 0;
  
    L_F_distance = 0;
    L_R_distance = 0;
    L_L_distance = 0;
    L_B_distance = 0;
    
    T_F_distance = 0;
    T_R_distance = 0;
    T_L_distance = 0;
    T_B_distance = 0;
    
    S_F_distance = 0;
    S_R_distance = 0;
    S_L_distance = 0;
    S_B_distance = 0;
    
    Z_F_distance = 0;
    Z_R_distance = 0;
    Z_L_distance = 0;
    Z_B_distance = 0;
    
    O_F_distance = 0;
    O_R_distance = 0;
    O_L_distance = 0;
    O_B_distance = 0;
    
    
    pos_uwb_raw =  zeros(2, max_step);
    pos_uwb = zeros(2, max_step);

    pos_center = zeros(4, 2, max_step);

    %heading = zeros(4, max_step);

    Grid_setup = zeros(grid_size(2),  grid_size(1));
    Grid_current =  zeros(grid_size(2),  grid_size(1), max_step);
    Grid_visited =  ones(grid_size(2),  grid_size(1), max_step)* grid_coverage_grid_default_value;
    Grid_obstacle = zeros(grid_size(2),  grid_size(1), max_step);
    for idxobs = 2:size(Map_obs,1)
        Grid_visited(Map_obs(idxobs,1),Map_obs(idxobs,2),1) = clims(1);
        Grid_obstacle(Map_obs(idxobs,1),Map_obs(idxobs,2),1) = 1;
    end

    robot_center_Grid = [];
    robot_Grid = [];

    prev_char_command = 'S';
    command_count_normal_linear = 0;
    command_count_rotation = 0;

    Dy_force = zeros(4, 2, max_step);
    Dy_a = zeros(4, 2, max_step);
    Dy_v = zeros(4, 2, max_step);

    is_rotating = false;

    Circle_Wp = [];
    Obstacles = [];

    Line_Linear_Route = [];

    Line_Robot = [];
    Line_Robot_area = [];
    Line_Border = [];
    loc_center = [0 0];

    is_transforming = false;


    for idx = 1:3
        RobotShapes = [RobotShapes; RobotShapes + pi/2*idx];
    end

    prev_heading_command_compensate = 0;
    heading_command_compensate = 0;

    char_command = 'S';
    grid_dhw = sqrt(2) / 2 * grid_w;

    Cvg = [];
    count_cvg_point = 0;
    cvg_sample_w = grid_w*[grid_size(2)/cvg_sample_side(1) grid_size(1)/cvg_sample_side(2)];
    count_pos_initialize = 0;
    is_pos_initialized = false;
    pos_initial = [];

    for idxx = 1:(cvg_sample_side(2)+1)
        for idxy = 1:(cvg_sample_side(1)+1)
            Cvg = [Cvg; cvg_sample_w(1)*(idxy-1) cvg_sample_w(2)*(idxx-1) 0];
        end
    end

    %% DRAW MAP


    figure(1)
    axis([-grid_w*1.5 grid_w*(grid_size(1)+1.5) -grid_w*1.5 grid_w*(grid_size(2)+1.5)])
    title('hTetro Waypoint Map')
    hold on


     % Draw Waypoints
    if (is_display_wp)
        for idx = 1: size(Wp,1)
            Circle_Wp(idx) = plot(Wp(idx, 1), Wp(idx, 2),'Color', 'r', 'LineWidth', 2, 'Marker', 'o');
        end
    end

    if (is_using_obs_map)
        if (is_display_obstacle)
            figure(1)
            for idxobs = 2:size(Map_obs,1)
                    Obstacles = rectangle('Position', [grid_w*(Map_obs(idxobs, :) - [1 1]), grid_w grid_w], ...
                                                    'FaceColor', [0 0 0]);
            end
        end
    end

    txt_endLine = [0 0];
    txt_endLine_last = [0 0];

    %% Square Waypoint  (SW)
    tic
    if (true)

        % Algorithm Setup
        occup_start = [2 1; 1 1; 1 2; 2 2];

        for idx = 1: 4
            Grid_current( occup_start( idx, 1), occup_start( idx, 2), 1) = idx ;
            Grid_visited( occup_start( idx, 1), occup_start( idx, 2), 1) = 1;
        end 
        pos_uwb_raw(:, 1) = pos_uwb_offset;
        pos_uwb(:, 1) = pos_uwb_raw(:, 1);

        % Algorithm Main Loop
        for step = 1:max_step

            % Pause function
            pause(time_pause);

            % Grid Info
            robot_center_Grid = [1+floor(pos_uwb(1, step)/grid_w) 1+floor(pos_uwb(2, step)/grid_w)];
            rotated_relative_grid_pos = rotationMatrix(Robot_Relative_Pos, Wp(wp_current, 3));
            robot_Grid = [ rotated_relative_grid_pos(1,:);
                                 0 0;
                                rotated_relative_grid_pos(2,:);
                                rotated_relative_grid_pos(3,:)] + robot_center_Grid;

            Grid_visited(:,:,step+1) = Grid_visited(:,:,step);
            for idxbox = 1:4
                if (robot_Grid(idxbox,1) > 0 && robot_Grid(idxbox,2) > 0 &&...
                        robot_Grid(idxbox,1) <= grid_size(1) && robot_Grid(idxbox,2) <= grid_size(2))
                    if (Grid_visited(robot_Grid(idxbox,1),robot_Grid(idxbox,2),step+1) == grid_coverage_grid_default_value)
                        Grid_visited(robot_Grid(idxbox,1),robot_Grid(idxbox,2),step+1) = 0;
                    else
                        if(~is_streaming_on)
                            Grid_visited(robot_Grid(idxbox,1),robot_Grid(idxbox,2),step+1) = ...
                                Grid_visited(robot_Grid(idxbox,1),robot_Grid(idxbox,2),step) + grid_coverage_sim_increase;
                        else
                            Grid_visited(robot_Grid(idxbox,1),robot_Grid(idxbox,2),step+1) = ...
                                Grid_visited(robot_Grid(idxbox,1),robot_Grid(idxbox,2),step) + grid_coverage_increase;
                        end
                    end
                end
            end
            if (is_display_grid_coverage_map)
                figure(2)
                title('hTetro Coverage Map')
                imagesc(flipud(transpose(Grid_visited(:,:,step+1))), clims)
                cmap = colormap(grid_coverage_colormap);
                cmap(1,:) = zeros(1,3);
                colormap(cmap);
                colorbar
                figure(1)
            end

            % Waypoint clearing
            %{
            if(norm(pos_uwb(:, step).' - Wp(wp_current, 1:2)) < tol_wp )
                if (is_display_wp && is_display_wp_clearing)
                    delete(Circle_Wp(wp_current));
                end
                wp_current = wp_current + 1;
                % Break condition
                if wp_current > size(Wp,1)
                    break;
                end
                heading_command_compensate = floor((Wp(wp_current, 3)-1)/7);
            end
            %}

            % Transformation
            is_require_transform = false;
            for rbtidx = 1:4
                if abs(heading(rbtidx) - RobotShapes(Wp(wp_current, 3),rbtidx)) > tol_transform
                    is_require_transform = true;
                end
            end

            if (robot_Form ~= Wp(wp_current, 3) && is_require_transform)
                if (command_count_rotation >= interval_rotation_command_send)
                    is_transforming = true;
                    if (is_xbee_on)
                        writedata = char(num2str(Wp(wp_current, 3)));
                        fwrite(arduino,writedata,'char');
                    end
                    prev_char_command = char(num2str(Wp(wp_current, 3)));
                    if (is_print_sent_commands) 
                        disp(['Time:', num2str(round(toc,2)), 's; Command Sent: ''' , num2str(Wp(wp_current, 3)), ''''])
                    end
                    command_count_rotation = 0;
                else
                    command_count_rotation = command_count_rotation + 1;
                end
            elseif (robot_Form ~= Wp(wp_current, 3) && ~is_require_transform)
                heading_command_compensate = floor((Wp(wp_current, 3)-1)/7);
                
                if mod(robot_Form, 7) == 2
                    if mod(Wp(wp_current, 3) , 7) == 3
                        count_OtoJ_tf = count_LtoJ_tf + 1;
                    elseif mod(Wp(wp_current, 3) , 7) == 4
                        count_OtoL_tf = count_LtoJ_tf + 1;
                    elseif mod(Wp(wp_current, 3) , 7) == 5
                        count_LtoJ_tf = count_LtoJ_tf + 1;
                    elseif mod(Wp(wp_current, 3) , 7) == 6
                        count_LtoJ_tf = count_LtoJ_tf + 1;
                    elseif mod(Wp(wp_current, 3) , 7) == 7
                        count_LtoJ_tf = count_LtoJ_tf + 1;
                    end
                    if dif == 1 || dif == -3
                        count_L_rot_clockwise = count_L_rot_clockwise + 1;
                    elseif  dif == 3 || dif == -1
                        count_L_rot_counterclockwise = count_L_rot_counterclockwise + 1;
                    elseif dif == 2 || -2
                        count_L_rot_180deg = count_L_rot_180deg + 1;
                    end
                elseif mod(robot_Form, 7) == 3
                    if mod(Wp(wp_current, 3) , 7) == 4
                        count_JtoL_tf = count_JtoL_tf + 1;
                    end
                    dif = heading_command_compensate-prev_heading_command_compensate;
                    
                    if dif == 1 || dif == -3
                        count_J_rot_clockwise = count_J_rot_clockwise + 1;
                    elseif  dif == 3 || dif == -1
                        count_J_rot_counterclockwise = count_J_rot_counterclockwise + 1;
                    elseif dif == 2 || -2
                        count_J_rot_180deg = count_J_rot_180deg + 1;
                    end
                    
                elseif mod(robot_Form, 7) == 4
                    if mod(Wp(wp_current, 3) , 7) == 3
                        count_LtoJ_tf = count_LtoJ_tf + 1;
                    end
                    if dif == 1 || dif == -3
                        count_L_rot_clockwise = count_L_rot_clockwise + 1;
                    elseif  dif == 3 || dif == -1
                        count_L_rot_counterclockwise = count_L_rot_counterclockwise + 1;
                    elseif dif == 2 || -2
                        count_L_rot_180deg = count_L_rot_180deg + 1;
                    end
                elseif mod(robot_Form, 7) == 5
                    if mod(Wp(wp_current, 3) , 7) == 3
                        count_LtoJ_tf = count_LtoJ_tf + 1;
                    end
                    if dif == 1 || dif == -3
                        count_L_rot_clockwise = count_L_rot_clockwise + 1;
                    elseif  dif == 3 || dif == -1
                        count_L_rot_counterclockwise = count_L_rot_counterclockwise + 1;
                    elseif dif == 2 || -2
                        count_L_rot_180deg = count_L_rot_180deg + 1;
                    end
                elseif mod(robot_Form, 7) == 6
                    if mod(Wp(wp_current, 3) , 7) == 3
                        count_LtoJ_tf = count_LtoJ_tf + 1;
                    end
                    if dif == 1 || dif == -3
                        count_L_rot_clockwise = count_L_rot_clockwise + 1;
                    elseif  dif == 3 || dif == -1
                        count_L_rot_counterclockwise = count_L_rot_counterclockwise + 1;
                    elseif dif == 2 || -2
                        count_L_rot_180deg = count_L_rot_180deg + 1;
                    end
               elseif mod(robot_Form, 7) == 7
                    if mod(Wp(wp_current, 3) , 7) == 3
                        count_LtoJ_tf = count_LtoJ_tf + 1;
                    end
                    if dif == 1 || dif == -3
                        count_L_rot_clockwise = count_L_rot_clockwise + 1;
                    elseif  dif == 3 || dif == -1
                        count_L_rot_counterclockwise = count_L_rot_counterclockwise + 1;
                    elseif dif == 2 || -2
                        count_L_rot_180deg = count_L_rot_180deg + 1;
                    end     
                end
                prev_heading_command_compensate = heading_command_compensate;
                robot_Form = Wp(wp_current, 3);
                is_transforming = false;
            end

            % Robot Motion
            if (~is_pos_initialized && is_streaming_on)
                pos_uwb(:, step+1) = pos_uwb(:, step);
            elseif (is_transforming)
                heading = robotTransformation(Wp(wp_current, 3), heading, RobotShapes, tol_transform, Dy_angv_transform);
                pos_uwb(:, step+1) = pos_uwb(:, step);
            elseif (heading(2) > tol_heading && is_sim_heading_correction ) 
                [Dy_v(:, :, step), heading] = robotMovement('l', heading, 0);
                pos_uwb(:, step+1) = pos_uwb(:, step);
            elseif (heading(2) < - tol_heading && is_sim_heading_correction) 
                [Dy_v(:, :, step), heading]  = robotMovement('r', heading, 0);
                pos_uwb(:, step+1) = pos_uwb(:, step);
            else
                % Waypoint navigation
                if (strcmp(navigation_mode,'MultipleRun'))
                    if abs(Wp(wp_current, 1) - pos_uwb(1,step)) > abs(Wp(wp_current, 2) - pos_uwb(2,step)) 
                        if Wp(wp_current, 1) - pos_uwb(1,step) > 0
                            char_command = Char_command_array_linear(1+mod(heading_command_compensate,4));  
                        else
                            char_command = Char_command_array_linear(1+mod(heading_command_compensate+2,4));
                        end
                    else
                        if Wp(wp_current, 2) - pos_uwb(2,step) > 0
                            char_command = Char_command_array_linear(1+mod(heading_command_compensate+1,4));
                        else
                            char_command = Char_command_array_linear(1+mod(heading_command_compensate+3,4));
                        end
                    end
                end
                % Movement for simulations
                if (~is_streaming_on && ~is_transforming)
                    [Dy_v(:, :, step), heading]  = robotMovement(char_command, heading, 2);
                    sim_noise = 0;
                    if (is_sim_normal_noise_on)
                        sim_noise = sim_noise + rand(2,1) * sim_noise_normal - sim_noise_normal/2.0;
                    end
                    if (is_sim_large_noise_y_on && rand < sim_noise_large_y_frequency) 
                        sim_noise = sim_noise + [0.5; rand] * sim_noise_large_y - sim_noise_large_y/2.0;
                    end
                    pos_uwb(:, step+1) = Dy_v(2, :, step).' * interval_system_time+ ...
                                                        update_rate_sim* (pos_uwb(:, step) + sim_noise)...
                                                       + (1 - update_rate_sim)* pos_uwb(:, step);
                    if mod(Wp(wp_current, 3) , 7) == 3
                        switch(char_command)
                            case 'F'
                                J_F_distance = J_F_distance + norm(pos_uwb(:,step+1)-pos_uwb(:,step));
                            case 'B'
                                J_B_distance = J_B_distance + norm(pos_uwb(:,step+1)-pos_uwb(:,step));
                            case 'R'
                                J_R_distance = J_R_distance + norm(pos_uwb(:,step+1)-pos_uwb(:,step));
                            case 'L'
                                J_L_distance = J_L_distance + norm(pos_uwb(:,step+1)-pos_uwb(:,step));
                        end
                    elseif  mod(Wp(wp_current, 3) , 7) == 4
                        switch(char_command)
                            case 'F'
                                L_F_distance = L_F_distance + norm(pos_uwb(:,step+1)-pos_uwb(:,step));
                            case 'B'
                                L_B_distance = L_B_distance + norm(pos_uwb(:,step+1)-pos_uwb(:,step));
                            case 'R'
                                L_R_distance = L_R_distance + norm(pos_uwb(:,step+1)-pos_uwb(:,step));
                            case 'L'
                                L_L_distance = L_L_distance + norm(pos_uwb(:,step+1)-pos_uwb(:,step));
                       end
                    end
                end
            end
          
            
            if(norm(pos_uwb(:, step+1).' - Wp(wp_current, 1:2)) < tol_wp && ~is_require_transform)
                if (is_display_wp && is_display_wp_clearing)
                    delete(Circle_Wp(wp_current));
                end
                wp_current = wp_current + 1;
                char_command = 'S';
                % Break condition
                if wp_current > size(Wp,1)
                    break;
                end

            end

            % Xbee Communication
            if (~is_transforming && ~strcmp(char_command,char(prev_char_command)) || (command_count_normal_linear >= interval_normal_linear_command_send))
                if (is_xbee_on)
                    writedata = char(char_command);
                    fwrite(arduino,writedata,'char');
                end
                prev_char_command = char_command;
                if (is_print_sent_commands) 
                end
                command_count_normal_linear = 0;
            else
                command_count_normal_linear = command_count_normal_linear + 1;
            end

            

            % calibrate pos here
            pos_x = pos_uwb(1,step);
            pos_nx = pos_uwb(1, step+1);
            pos_y = pos_uwb(2,step);
            pos_ny = pos_uwb(2, step+1);

            distance_travelled = distance_travelled + norm(pos_uwb(:,step+1)-pos_uwb(:,step));
            
            %% Figure!!

            % remove previous robot line plot
            if (~isempty(Line_Robot))
                delete(Line_Robot)
                delete(Line_Linear_Route)
            end
            Line_Robot = [];
            Line_Border = [];
            Line_Linear_Route = [];

            % Determine Robot center
            pos_center(2,:, step) = [pos_x pos_y];
            pos_center(1,:, step) =  pos_center(2,:,step) + grid_dhw* ...
                                       [sin(pi/4 - heading(2))-cos(pi/4 - heading(1)) ...
                                        -cos(pi/4 - heading(2))-sin(pi/4 - heading(1))];
            pos_center(3,:, step) =  pos_center(2,:,step) + grid_dhw* ...
                                       [cos(pi/4 - heading(2))+sin(heading(3) - pi/4) ...
                                        sin(pi/4 - heading(2))+cos(heading(3) - pi/4)];
            pos_center(4,:, step) =  pos_center(3,:,step) + grid_dhw* ...
                                       [sin(-pi/4 + heading(3))+sin(pi/4 + heading(4)) ...
                                        cos(-pi/4 + heading(3))+cos(pi/4 + heading(4))]; 

            pos_center(2,:, step+1) = [pos_nx pos_ny];
            pos_center(1,:, step+1) =  pos_center(2,:, step+1) + grid_dhw* ...
                                       [sin(pi/4 - heading(2))-cos(pi/4 - heading(1)) ...
                                        -cos(pi/4 - heading(2))-sin(pi/4 - heading(1))];
            pos_center(3,:, step+1) =  pos_center(2,:, step+1) + grid_dhw* ...
                                       [cos(pi/4 - heading(2))+sin(heading(3) - pi/4) ...
                                        sin(pi/4 - heading(2))+cos(heading(3) - pi/4)];
            pos_center(4,:, step+1) =  pos_center(3,:,step+1)  + grid_dhw* ...
                                       [sin(-pi/4 + heading(3))+sin(pi/4 + heading(4)) ...
                                        cos(-pi/4 + heading(3))+cos(pi/4 + heading(4))]; 

                                    
                                    

            % plot robot BG
            if (is_display_coverage_map == true)
                for robidx = 1:4
                Line_Robot(robidx,1) = line([pos_center(robidx, 1, step)+grid_dhw*cos(pi/4 - heading(robidx)) ...
                                                         pos_center(robidx, 1, step)+grid_dhw*sin(pi/4 - heading(robidx))], ...
                                                        [pos_center(robidx, 2, step)+grid_dhw*sin(pi/4 -  heading(robidx)) ...
                                                         pos_center(robidx, 2, step)+grid_dhw*-cos(pi/4 -  heading(robidx))], 'Color', 'cyan', 'LineWidth', 5);
                Line_Robot(robidx,2) = line([pos_center(robidx, 1, step)+grid_dhw*cos(pi/4 -  heading(robidx))... 
                                                         pos_center(robidx, 1, step)+grid_dhw*-sin(pi/4 -  heading(robidx))], ...
                                                        [ pos_center(robidx, 2, step)+grid_dhw*sin(pi/4 -  heading(robidx))...
                                                          pos_center(robidx, 2, step)+grid_dhw*cos(pi/4 -  heading(robidx))], 'Color', 'cyan', 'LineWidth', 5);
                Line_Robot(robidx,3) = line([pos_center(robidx, 1, step)+grid_dhw*-cos(pi/4 -  heading(robidx)) ...
                                                         pos_center(robidx, 1, step)+grid_dhw*-sin(pi/4 -  heading(robidx))], ...
                                                        [ pos_center(robidx, 2, step)+grid_dhw*-sin(pi/4 -  heading(robidx)) ...
                                                          pos_center(robidx, 2, step)+grid_dhw*cos(pi/4 -  heading(robidx))], 'Color', 'cyan', 'LineWidth', 5);
                Line_Robot(robidx,4) = line([pos_center(robidx, 1, step)+grid_dhw*-cos(pi/4 -  heading(robidx)) ...
                                                         pos_center(robidx, 1, step)+grid_dhw*sin(pi/4 -  heading(robidx))], ...
                                                        [ pos_center(robidx, 2, step)+grid_dhw*-sin(pi/4 -  heading(robidx))...
                                                          pos_center(robidx, 2, step)+grid_dhw*-cos(pi/4 -  heading(robidx))], 'Color', 'cyan', 'LineWidth', 5);
                 end
            end
            
            if (is_display_wp)
                for idx = 1: size(Wp,1)
                    Circle_Wp(idx) = plot(Wp(idx, 1), Wp(idx, 2),'Color', 'r', 'LineWidth', 2, 'Marker', 'o');
                end
            end
            
            % Draw Outer Border
            Line_Border(1) = line([0 0], [0 grid_w*grid_size(2)], 'Color', 'black', 'LineWidth', 2);
            Line_Border(2) =line([0 grid_w*grid_size(1)], [0 0], 'Color', 'black', 'LineWidth', 2);
            Line_Border(3) =line([grid_w*grid_size(1) 0], [grid_w*grid_size(2) grid_w*grid_size(2)], 'Color', 'black', 'LineWidth', 2);
            Line_Border(4) =line([grid_w*grid_size(1) grid_w*grid_size(1)], [grid_w*grid_size(2) 0], 'Color', 'black', 'LineWidth', 2);


            if (is_display_grid_on)
                for idxx = 1:(grid_size(1) + 1)
                    line(grid_w*[(idxx-1) (idxx-1)], grid_w*[0 grid_size(2)], 'Color', 'black', 'LineWidth', 0.5);
                end
                for idxy = 1:(grid_size(2) + 1)
                    line(grid_w*[0 grid_size(1)], grid_w*[(idxy-1) (idxy-1)], 'Color', 'black', 'LineWidth', 0.5);
                end
            end

            % Draw Robot Tracks
            % TODO: track rotation!
            if (strcmp(navigation_mode,'Line') && is_display_route)
                if (is_display_route_clearing)
                    wpidx_begin = wp_current;
                else 
                    wpidx_begin = 2;
                end
                for wpidx = wpidx_begin : size(Wp,1)
                    if (Wp(wpidx, 4) ~= 1)
                        route_norm_vector = null(Wp(wpidx, 1:2) - Wp(wpidx-1, 1:2)).';
                        line_linear_route_v1 = Wp(wpidx-1, 1:2) - route_norm_vector()*tol_line_width;
                        line_linear_route_v2 = Wp(wpidx, 1:2) + route_norm_vector()*tol_line_width;
                        line_linear_route_x = [line_linear_route_v1(1) line_linear_route_v2(1) line_linear_route_v2(1) line_linear_route_v1(1) line_linear_route_v1(1)];
                        line_linear_route_y = [line_linear_route_v1(2) line_linear_route_v1(2) line_linear_route_v2(2) line_linear_route_v2(2) line_linear_route_v1(2)];
                        %{route_norm_vector = null(Wp(Wpidx, 1:2) - Wp(Wpidx, 1:2)).';
                        Line_Linear_Route = [ Line_Linear_Route, plot(line_linear_route_x, line_linear_route_y, 'b-')]; 
                    end
                end
            end

            % Draw Robot Outline
            for robidx = 1:4
                %line([pos_center(robidx,1,step) pos_center(robidx,1,step+1)], [pos_center(robidx,2,step) pos_center(robidx,2,step+1)])  
                Line_Robot(robidx,1) = line([pos_center(robidx, 1, step)+grid_dhw*cos(pi/4 - heading(robidx)) ...
                                                         pos_center(robidx, 1, step)+grid_dhw*sin(pi/4 - heading(robidx))], ...
                                                        [pos_center(robidx, 2, step)+grid_dhw*sin(pi/4 -  heading(robidx)) ...
                                                         pos_center(robidx, 2, step)+grid_dhw*-cos(pi/4 -  heading(robidx))], 'Color', 'green', 'LineWidth', 3);
                Line_Robot(robidx,2) = line([pos_center(robidx, 1, step)+grid_dhw*cos(pi/4 -  heading(robidx))... 
                                                         pos_center(robidx, 1, step)+grid_dhw*-sin(pi/4 -  heading(robidx))], ...
                                                        [ pos_center(robidx, 2, step)+grid_dhw*sin(pi/4 -  heading(robidx))...
                                                          pos_center(robidx, 2, step)+grid_dhw*cos(pi/4 -  heading(robidx))], 'Color', 'green', 'LineWidth', 3);
                Line_Robot(robidx,3) = line([pos_center(robidx, 1, step)+grid_dhw*-cos(pi/4 -  heading(robidx)) ...
                                                         pos_center(robidx, 1, step)+grid_dhw*-sin(pi/4 -  heading(robidx))], ...
                                                        [ pos_center(robidx, 2, step)+grid_dhw*-sin(pi/4 -  heading(robidx)) ...
                                                          pos_center(robidx, 2, step)+grid_dhw*cos(pi/4 -  heading(robidx))], 'Color', 'green', 'LineWidth', 3);
                Line_Robot(robidx,4) = line([pos_center(robidx, 1, step)+grid_dhw*-cos(pi/4 -  heading(robidx)) ...
                                                         pos_center(robidx, 1, step)+grid_dhw*sin(pi/4 -  heading(robidx))], ...
                                                        [ pos_center(robidx, 2, step)+grid_dhw*-sin(pi/4 -  heading(robidx))...
                                                          pos_center(robidx, 2, step)+grid_dhw*-cos(pi/4 -  heading(robidx))], 'Color', 'green', 'LineWidth', 3);   
            end

            if(is_calculate_coverage)
                for cvg_idx = 1: numel(Cvg(:, 1))
                    if (abs(pos_center(2, :, step)-Cvg(cvg_idx, 1:2)) < 2.5*sqrt(2)*grid_w)
                        for robidx = 1:4
                            if (Cvg(cvg_idx, 3) == 0)
                                tri1_x = [pos_center(robidx, 1, step)+grid_dhw*cos(pi/4 - heading(robidx)) ...
                                              pos_center(robidx, 1, step)+grid_dhw*sin(pi/4 - heading(robidx)) ...
                                              Cvg(cvg_idx, 1)];
                                tri1_y = [pos_center(robidx, 2, step)+grid_dhw*sin(pi/4 -  heading(robidx))  ...
                                              pos_center(robidx, 2, step)+grid_dhw*-cos(pi/4 -  heading(robidx)) ...
                                              Cvg(cvg_idx, 2)];
                                area1 = polyarea(tri1_x,tri1_y);
                                tri2_x = [pos_center(robidx, 1, step)+grid_dhw*cos(pi/4 -  heading(robidx)) ...
                                              pos_center(robidx, 1, step)+grid_dhw*-sin(pi/4 -  heading(robidx)) ...
                                              Cvg(cvg_idx, 1)];
                                tri2_y = [pos_center(robidx, 2, step)+grid_dhw*sin(pi/4 -  heading(robidx))  ...
                                              pos_center(robidx, 2, step)+grid_dhw*cos(pi/4 -  heading(robidx)) ...
                                              Cvg(cvg_idx, 2)];
                                area2 = polyarea(tri1_x,tri1_y);
                                tri3_x = [pos_center(robidx, 1, step)+grid_dhw*-cos(pi/4 -  heading(robidx)) ...
                                              pos_center(robidx, 1, step)+grid_dhw*-sin(pi/4 - heading(robidx)) ...
                                              Cvg(cvg_idx, 1)];
                                tri3_y = [pos_center(robidx, 2, step)+grid_dhw*-sin(pi/4 -  heading(robidx))  ...
                                              pos_center(robidx, 2, step)+grid_dhw*cos(pi/4 -  heading(robidx)) ...
                                              Cvg(cvg_idx, 2)];
                                area3 = polyarea(tri3_x,tri3_y);
                                tri4_x = [pos_center(robidx, 1, step)+grid_dhw*-cos(pi/4 -  heading(robidx)) ...
                                              pos_center(robidx, 1, step)+grid_dhw*sin(pi/4 -  heading(robidx)) ...
                                              Cvg(cvg_idx, 1)];
                                tri4_y = [pos_center(robidx, 2, step)+grid_dhw*-sin(pi/4 -  heading(robidx)) ...
                                              pos_center(robidx, 2, step)+grid_dhw*-cos(pi/4 -  heading(robidx)) ...
                                              Cvg(cvg_idx, 2)];
                                area4 =  polyarea(tri4_x,tri4_y);
                                if area1 + area2 + area3 + area4 <= grid_w* grid_w + 0.1
                                    Cvg(cvg_idx,3) = 1;
                                    count_cvg_point = count_cvg_point+1;
                                end
                            end
                        end
                    end
                end
                if (is_print_coverage)
                    disp(['Coverage: ',  num2str(count_cvg_point*100 / numel(Cvg(:, 1))), ' %']);
                end
            end
            % Draw Robot Center
            line([pos_x pos_nx], [pos_y pos_ny])

        end
    end

    if (is_xbee_on)
         writedata = char('S');
         fwrite(arduino,writedata,'char');
    end

    disp('===================');
    disp(['Tiling Set: ', num2str(run)])
    disp('Robot Navigation Completed!');
    toc
    hold off
    if (is_calculate_coverage)
        disp(['Final Map Coverage: ',  num2str(count_cvg_point*100 / numel(Cvg(:, 1))), ' %']);
        %disp(['Total Distance Travelled: ',  num2str(distance_travelled), ' cm']);
        %disp(['L rotation angle: ',  num2str(count_L_rot_clockwise), ' degrees']);
        %disp(['J rotation angle: ',  num2str(count_J_rot), ' degrees']);
        %disp(['L to J  transformation: ',  num2str(count_LtoJ_tf), ' times']);
        %disp(['J to L  transformation: ',  num2str(count_JtoL_tf), ' times']);
    end
    
    Name = {'TilingSet'; 'L rotation 90deg clockwise'; 'L rotation 90deg counterclockwise';...
              'L rotation 180deg turn';'J rotation 90deg clockwise'; 'J rotation 90deg counterclockwise'; ...
              'J rotation 180deg turn';'L to J  transformation'; 'J to L  transformation';
               'J F_distance';'J R_distance';  'J B_distance';'J L_distance'; ...
               'L F_distance';'L R_distance';  'L B_distance';'L L_distance'};
    Data = [run;
                     count_L_rot_clockwise;
                     count_L_rot_counterclockwise;
                     count_L_rot_180deg;
                    count_J_rot_clockwise;
                    count_J_rot_counterclockwise;
                     count_J_rot_180deg;                   
                      count_LtoJ_tf;
                     count_JtoL_tf;
                    J_B_distance;
                    J_L_distance;
                    J_F_distance;
                    J_R_distance;
                    L_B_distance;
                    L_L_distance;
                    L_F_distance;
                    L_R_distance];
    T = table(Data, 'RowNames', Name);
    writetable(T,['TilingSet' ,num2str(run) ,'.csv'],'WriteRowNames',true);
    
    %saveas(figure(1),['TilingSet' +num2str(run) +'.jpg']);
end