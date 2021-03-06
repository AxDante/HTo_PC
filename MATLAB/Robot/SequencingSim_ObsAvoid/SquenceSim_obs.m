cla
close all;
clc;

%% Variable Setup

addpath([erase(mfilename('fullpath'),mfilename), 'map'])


file_map = 'obs2';   % Set Map as 'Empty' for empty map
WaypointMapMode = 'obs2';
wp_run =3;
starting_pause_time = 1;

grid_size = [10 10];   % Assign values for grid size if an empty map is chosen
grid_w = 25;    % Grid width (unit:cm)

tol_wp = 2; %18    % Waypoint tolerance (unit:cm)               
tol_line_width =  10; %12;    % Route deviation tolerance (unit:cm)

cvg_sample_side = [20 20];  % Robot map coverage samples size 

grid_coverage_sample_size = [100 100];


% Algorithms
navigation_mode = 'MultipleRun';
zigzag_mode = 'simple';

% Time Frame Setup
max_step = 5000;   % Maximum system steps
interval_system_time = 1;   % Robot dynamics update intervals
interval_rotation_command_send = 10;    % Robot rotation commands sending interval


% Grid Map Setup
clims = [-1000, 800];  % Grid color map limits
grid_coverage_grid_default_value = -900;
grid_coverage_colormap = 'jet'; % Colormap format
grid_coverage_sim_increase = 8; % Grid color map value increased for each step during simulation;
grid_coverage_increase = 1; % Grid color map value increased for each step during robot demo;

% Robot Dynamics Setup
robot_Form = 11; % Robot starting shape
tol_transform = pi/50;  % Robot Transformation angle tolerance (unit:rad)
Dy_angv_transform = pi/2;  % Robot transformation angular velocity (unit:rad)
tol_heading = pi/7; % Robot heading deviation tolerance (unit:rad)

update_rate_streaming = 1;  % Robot position update rate during data streaming
update_rate_streaming_single_value = 1; % Robot position update rate during data streaming with single values
update_rate_sim = 1; % Robot position update rate during simulation

% Toggle 

is_display_wp_map = false;
is_display_grid_coverage_map = false;

is_calculate_coverage = true;
is_calculate_grid_coverage_duration = false;
is_display_wp = true;
is_display_wp_clearing = true;
is_display_rbt_center = true;
is_display_grid_on = true;
is_display_obstacle = true;
is_print_coverage = false;
is_print_sent_commands = false;
is_sim_normal_noise_on= false;
is_sim_large_noise_y_on = false;
is_sim_heading_correction = false;

% Simulation Setup
sim_noise_normal = 20;  % Noise value during simulation (unit: cm)
sim_noise_large_y_frequency = 0.05; % Frequency of large Y axis noise during simulation 
sim_noise_large_y = 50; % large Y axis noise value during simulation (unit: cm)

%% Variable initialization

is_using_obs_map = false;
Map_obs = [];
Map_obs_temp = [];
if exist(['map/',file_map, '.txt'], 'file') == 2
    Map_obs_temp = csvread([file_map, '.txt']);
    disp(['Map: ', file_map, '.txt loaded successfully!']);
    grid_size = Map_obs_temp(1,:);
    Map_obs(:,1) = Map_obs_temp(:,2);
    Map_obs(:,2) = grid_size(1)+1-Map_obs_temp(:,1); 
    is_using_obs_map = true;
else
    disp(['Default map loaded successfully!']);
end

RobotShapes = [];
initRobotShapes = [0 0 0 0 ;              
                        0 0 pi pi;
                        -pi 0 pi/2 -pi/2;
                        -pi 0 0 0;
                        -pi 0 0 -pi;
                        -pi/2 0 pi 0;
                        -pi 0 pi/2 pi/2];

time_pause = interval_system_time/2000;

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

    Robot_Relative_Pos = [0 -1; 0 1; 0 2;
                                     0 -1; 1 0; 1 -1;
                                     -1 0; 0 1; 1 1;
                                     -1 0; 0 1; 0 2;
                                     1 0; 0 1; -1 1;
                                     1 -1; 1 0; 2 0;
                                     1 -1; 1 0; 2 -1];


    Char_command_array_linear = ['R', 'F', 'L', 'B'];
    Char_command_array_linear_adjustment =  ['r', 'f', 'l', 'b'];
    
Robot_center = [];
    
    
%% Waypoint Generation
%Wp_series = {};
if (strcmp(navigation_mode,'MultipleRun'))
    disp('Generating waypoints...')
    [Wp_series, Wp_hack_series] = MultipleRunImport_Veera(grid_size, grid_w, WaypointMapMode);
else
    disp('Navigation method is invalid.')
    disp('Terminating Matlab script...')
    return
end


for run = wp_run
    
    clf

    Wp = Wp_series{run};
    Wp_hack = Wp_hack_series{run};
    pos_uwb_offset = Wp(1, 1:2);
    wp_current = 1;
    distance_travelled = 0;
    
    robot_Form = Wp(1,3); % Robot starting shape
    heading = floor((Wp(1,3)-1)/7)*pi/2+initRobotShapes(mod(Wp(1,3)-1,7)+1, :);
    
    pos_uwb_raw =  zeros(2, max_step);
    pos_uwb = zeros(2, max_step);

    pos_center = zeros(4, 2, max_step);

    Grid_coverage = ones(grid_coverage_sample_size(1),grid_coverage_sample_size(2),max_step)*grid_coverage_grid_default_value;

    robot_center_Grid = [];
    robot_Grid = [];

    prev_char_command = 'S';
    command_count_normal_linear = 0;
    command_count_rotation = 0;

    Dy_v = zeros(4, 2, max_step);

    is_rotating = false;

    Circle_Wp = [];
    Obstacles = [];
    Line_Robot = [];
    Line_Robot_area = [];
    Line_gridx = [];
    Line_gridy = [];
    Line_Border = []; 

    is_transforming = false;

    RobotShapes = [initRobotShapes; initRobotShapes + pi/2*1];
    RobotShapes = [RobotShapes; initRobotShapes + pi/2*2];
    RobotShapes = [RobotShapes; initRobotShapes - pi/2*1];
    
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
    
    if (is_display_wp_map)
        figure(1);
        set(figure(1), 'Position', [720, 495, 560, 500])
        marginspace = 0;
        axis([-grid_w*marginspace grid_w*(grid_size(2)+marginspace) -grid_w*marginspace grid_w*(grid_size(1)+marginspace)])
        title('hTetro Waypoint Sequence Map')
        hold on
    
     % Draw Waypoints
    if (is_display_wp)
        for idx = 1: size(Wp_hack,1)
            Circle_Wp(idx) = plot(Wp_hack(idx, 1), Wp_hack(idx, 2),'Color', 'r', 'LineWidth', 2, 'Marker', 'o');
        end
    end

    if (is_using_obs_map)
        if (is_display_obstacle)
            for idxobs = 2:size(Map_obs,1)
                    Obstacles = rectangle('Position', [grid_w*(Map_obs(idxobs, :) - [1 1]), grid_w grid_w], ...
                                                    'FaceColor', [0 0 0]);
            end
        end
    end
    end

    txt_endLine = [0 0];
    txt_endLine_last = [0 0];

    %% Square Waypoint  (SW)
    tic
    if (true)
        
        % Algcorithm Setup
        
        pos_uwb_raw(:, 1) = pos_uwb_offset;
        pos_uwb(:, 1) = pos_uwb_raw(:, 1);

        % Algorithm Main Loop
        for step = 1: max_step

            updateCoverageMap = false;
            
            % Pause function
            pause(time_pause);
            
            % Grid Info
            robot_center_Grid = [1+floor(pos_uwb(1, step)/grid_w) 1+floor(pos_uwb(2, step)/grid_w)];
            rotated_relative_grid_pos = rotationMatrix(Robot_Relative_Pos, Wp(wp_current, 3));
            robot_Grid = [ rotated_relative_grid_pos(1,:);
                                 0 0;
                                rotated_relative_grid_pos(2,:);
                                rotated_relative_grid_pos(3,:)] + robot_center_Grid;

            % Waypoint clearing
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
                    prev_char_command = char(num2str(Wp(wp_current, 3)));
                    if (is_print_sent_commands) 
                        disp(['Time:', num2str(round(toc,2)), 's; Command Sent: ''' , num2str(Wp(wp_current, 3)), ''''])
                    end
                    command_count_rotation = 0;
                else
                    command_count_rotation = command_count_rotation + 1;
                end
            else 
                robot_Form = Wp(wp_current, 3);
                heading_command_compensate = floor((Wp(wp_current, 3)-1)/7);
                is_transforming = false;
                prev_heading_command_compensate = heading_command_compensate;
            end

            % Robot Motion
            if (is_transforming)
                heading = robotTransformation(Wp(wp_current, 3), heading, RobotShapes, tol_transform, Dy_angv_transform);
                pos_uwb(:, step+1) = pos_uwb(:, step);
                updateCoverageMap = true;
            elseif (heading(2) > tol_heading && is_sim_heading_correction ) 
                [Dy_v(:, :, step), heading] = robotMovement('l', heading, 0);
                pos_uwb(:, step+1) = pos_uwb(:, step);
                updateCoverageMap = true;
            elseif (heading(2) < - tol_heading && is_sim_heading_correction) 
                [Dy_v(:, :, step), heading]  = robotMovement('r', heading, 0);
                pos_uwb(:, step+1) = pos_uwb(:, step);
                updateCoverageMap = true;
            else
                % Waypoint navigation
                updateCoverageMap = true;
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
                if (~is_transforming)
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
                end
            end
          
            
            if(norm(pos_uwb(:, step+1).' - Wp(wp_current, 1:2)) < tol_wp )
                wp_current = wp_current + 1;
                char_command = 'S';
                % Break condition
                if wp_current > size(Wp,1)
                    break;
                end
            end
            % calibrate pos here
            pos_x = pos_uwb(1,step);
            pos_nx = pos_uwb(1, step+1);
            pos_y = pos_uwb(2,step);
            pos_ny = pos_uwb(2, step+1);

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
            
            distance_travelled = distance_travelled + norm(pos_uwb(:,step+1)-pos_uwb(:,step));
            
          %% Figure!!
          
            if (is_display_wp_map)
                figure(1);
                % remove previous robot line plot

                if (is_display_wp_clearing)
                    if (~isempty(Circle_Wp))
                        delete(Circle_Wp);
                    end
                    
                    Circle_Wp = [];
                        for idx = wp_current: size(Wp,1)
                            newIndex = find( ismember(Wp_hack,Wp(idx,:),'row'),1);
                            if (~isempty(newIndex))
                                Circle_Wp(idx) = plot(Wp_hack(newIndex, 1),Wp_hack(newIndex, 2),'Color', 'r', 'LineWidth', 3, 'Marker', 'o');
                            end
                        end
                end
                
                Line_Border = [];
                if (~isempty(Line_Border))
                    delete(Line_Border);
                end
                % Draw Outer Border
                Line_Border(1) = line([0 0], [0 grid_w*grid_size(1)], 'Color', 'black', 'LineWidth', 2);
                Line_Border(2) =line([0 grid_w*grid_size(2)], [0 0], 'Color', 'black', 'LineWidth', 2);
                Line_Border(3) =line([grid_w*grid_size(2) 0], [grid_w*grid_size(1) grid_w*grid_size(1)], 'Color', 'black', 'LineWidth', 2);
                Line_Border(4) =line([grid_w*grid_size(2) grid_w*grid_size(2)], [grid_w*grid_size(1) 0], 'Color', 'black', 'LineWidth', 2);

                
                Line_gridx = [];
                Line_gridy = [];
                if (~isempty(Line_gridx))
                    delete(Line_gridx);
                end
                if (~isempty(Line_gridy))
                    delete(Line_gridy);
                end
                if (is_display_grid_on)
                    for idxx = 1:(grid_size(2) + 1)
                        Line_gridx(idxx)=line(grid_w*[(idxx-1) (idxx-1)], grid_w*[0 grid_size(1)], 'Color', 'black', 'LineWidth', 0.5);
                    end
                    for idxy = 1:(grid_size(1) + 1)
                        Line_gridy(idxy)=line(grid_w*[0 grid_size(2)], grid_w*[(idxy-1) (idxy-1)], 'Color', 'black', 'LineWidth', 0.5);
                    end
                end

                % Draw Robot Outline

                if (~isempty(Line_Robot))
                    delete(Line_Robot);
                end
                Line_Robot = [];

                for robidx = 1:4
                   % line([pos_x pos_nx], [pos_y pos_ny])
                    Line_Robot(robidx,1) = line([pos_center(robidx, 1, step)+grid_dhw*cos(pi/4 - heading(robidx)) ...
                                                             pos_center(robidx, 1, step)+grid_dhw*sin(pi/4 - heading(robidx))], ...
                                                            [pos_center(robidx, 2, step)+grid_dhw*sin(pi/4 -  heading(robidx)) ...
                                                             pos_center(robidx, 2, step)+grid_dhw*-cos(pi/4 -  heading(robidx))], 'Color', [77, 77, 255]/255, 'LineWidth', 3);
                    Line_Robot(robidx,2) = line([pos_center(robidx, 1, step)+grid_dhw*cos(pi/4 -  heading(robidx))... 
                                                             pos_center(robidx, 1, step)+grid_dhw*-sin(pi/4 -  heading(robidx))], ...
                                                            [ pos_center(robidx, 2, step)+grid_dhw*sin(pi/4 -  heading(robidx))...
                                                              pos_center(robidx, 2, step)+grid_dhw*cos(pi/4 -  heading(robidx))], 'Color',  [77, 77, 255]/255, 'LineWidth', 3);
                    Line_Robot(robidx,3) = line([pos_center(robidx, 1, step)+grid_dhw*-cos(pi/4 -  heading(robidx)) ...
                                                             pos_center(robidx, 1, step)+grid_dhw*-sin(pi/4 -  heading(robidx))], ...
                                                            [ pos_center(robidx, 2, step)+grid_dhw*-sin(pi/4 -  heading(robidx)) ...
                                                              pos_center(robidx, 2, step)+grid_dhw*cos(pi/4 -  heading(robidx))], 'Color',  [77, 77, 255]/255, 'LineWidth', 3);
                    Line_Robot(robidx,4) = line([pos_center(robidx, 1, step)+grid_dhw*-cos(pi/4 -  heading(robidx)) ...
                                                             pos_center(robidx, 1, step)+grid_dhw*sin(pi/4 -  heading(robidx))], ...
                                                            [ pos_center(robidx, 2, step)+grid_dhw*-sin(pi/4 -  heading(robidx))...
                                                              pos_center(robidx, 2, step)+grid_dhw*-cos(pi/4 -  heading(robidx))], 'Color', [77, 77, 255]/255, 'LineWidth', 3);   
                end
            end
            
        
            Grid_coverage(:,:,step+1) = Grid_coverage(:,:,step);
            if(is_calculate_coverage && updateCoverageMap && ~is_transforming)
                grid_coverage_sample_w = grid_size*grid_w./grid_coverage_sample_size;
                for  idxx = 1:grid_coverage_sample_size(1)
                    for idxy = 1:grid_coverage_sample_size(2)
                        sample_pos = [(idxx-0.5)*grid_coverage_sample_w(2) (idxy-0.5)*grid_coverage_sample_w(1)];
                        if (norm(pos_center(2, :, step)-sample_pos) < 3*sqrt(2)*grid_w)
                            for robidx = 1:4
                                if (abs(sample_pos(1)-pos_center(robidx, 1, step)) <= grid_w/2+0.2) && (abs(sample_pos(2)-pos_center(robidx, 2, step)) <= grid_w/2+0.2)
                                    if (Grid_coverage(idxx,idxy,step+1) <= -10)
                                        Grid_coverage(idxx,idxy,step+1) = 0;
                                    else
                                        Grid_coverage(idxx,idxy,step+1) = Grid_coverage(idxx,idxy,step) + 4;
                                    end
                                end
                            end
                        end
                    end
                end
            
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
            
            if (is_display_grid_coverage_map)
                figure(2)
                set(figure(2),'Position', [1290, 495, 630, 500])
                title('hTetro Coverage Heat Map')
                imagesc(flipud(transpose(Grid_coverage(:,:,step+1))), clims)
                cmap = colormap(grid_coverage_colormap);
                cmap(1,:) = zeros(1,3);
                colormap(cmap);
                colorbar
            end
            
            Robot_center(step,1,1:2) = [pos_x pos_nx];
            Robot_center(step,2,1:2) = [pos_y pos_ny];
            
            if (step == 1)
                figure(2)
                set(figure(2),'Position', [1290, 495, 630, 500])
                title('hTetro Coverage Heat Map')
                imagesc(flipud(transpose(Grid_coverage(:,:,step+1))), clims)
                cmap = colormap(grid_coverage_colormap);
                cmap(1,:) = zeros(1,3);
                colormap(cmap);
                colorbar
                pause(starting_pause_time)
            end
        end
    end
    
    disp('===================');
    disp(['Tiling Set: ', num2str(run)])
    disp('Robot Navigation Completed!');
    toc
    hold off
    
    coverage_Array = Grid_coverage(:,:,step);
    num_ele = 0;
    tot_ele = 0;
    for eleidx = 1:numel(coverage_Array)
        if coverage_Array(eleidx) >= 0
            num_ele = num_ele + 1;
            tot_ele = tot_ele + coverage_Array(eleidx);
        end
    end
    num_ele = 10000* (1-(size(Map_obs,1)-1)/(grid_size(1)*grid_size(2)));
    avg_grid_spent_time = (tot_ele/num_ele/4);
    
    if (is_calculate_coverage)
        
        disp(['Final Map Coverage: ',  num2str(count_cvg_point*100 / numel(Cvg(:, 1))), ' %']);
        disp(['Average Grid Spent Time: ',  num2str(avg_grid_spent_time), '']);
        disp(['Total Distance Travelled: ',  num2str(distance_travelled), ' cm']);
        
        figure(2);
        set(figure(2),'Position', [1290, 495, 630, 500])
        title('hTetro Coverage Heat Map')
        imagesc(flipud(transpose(Grid_coverage(:,:,step))), clims)
        cmap = colormap(grid_coverage_colormap);
        cmap(1,:) = zeros(1,3);
        colormap(cmap);
        colorbar
        hold on
    end
    
    figure(1)
    figure(2)
end