function  Dy_v_t = robotTransformation(char_command_t, robot_heading_t, speed_t)
    for idx_t = 1:4
        switch char_command_t
            case 'F'
                Dy_v_t(idx_t, :) = [sin(robot_heading_t) cos(robot_heading_t)]* speed_t;
            case 'R'
                Dy_v_t(idx_t, :) = [cos(robot_heading_t) -sin(robot_heading_t)]* speed_t;
            case 'B'
                Dy_v_t(idx_t, :) = [-sin(robot_heading_t) -cos(robot_heading_t)]* speed_t;
            case 'L'
                Dy_v_t(idx_t, :) = [-cos(robot_heading_t) sin(robot_heading_t)]* speed_t;
        end
    end
end