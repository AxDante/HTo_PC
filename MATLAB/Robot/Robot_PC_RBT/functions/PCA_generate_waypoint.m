function [Wp, Wp_hack] = PCA_generate_waypoint(gs, gw, Gobs)
    
    start_shape = 2;
    rcg = [2 2];
    Wp_hack2 = [9 2 2;
                   9 3 2;
                   2 3 2;
                   2 6 2;
                   9 6 2;
                   9 8 2;
                   2 7 2;
                   2 9 2;
                   9 10 2];
   
   Wp_hack = [18 2 2;
                   18 4 2;
                   2 4 2;
                   2 6 2;
                   18 6 2;
                   18 8 2;
                   2 8 2;
                   2 10 2;
                   18 10 2];           
               
    Row_sweep = [1 2;
                         0 0;
                         3 4;
                         0 0;
                         5 6;
                         0 0;
                         7 8;
                         0 0;
                         9 10];
   
                     
    Row_sweep_dir = [1; 0; -1; 0; 1; 0; -1; 0; 1];
                     
    Gvis = zeros(gs(1),gs(2));
    for obsidx = 1:size(Gobs,1)
        Gvis(Gobs(obsidx,1), Gobs(obsidx,2)) = -1;
    end
  
    for rowidx = 1:gs(1)
        for colidx = 1:gs(2)
             GA{rowidx,colidx} = checkGridAvalibility(rowidx,colidx, gs, Gobs);
             GSC{rowidx,colidx} = checkGridShapeChange(rowidx,colidx, gs, Gobs);
        end
    end
    
    scg = rcg;
    Wp = [];
    
    for idx = 1: 4 %size(Wp_hack,1)
        gcg = [ceil(Wp_hack(idx,1)) ceil(Wp_hack(idx,2))];
        if (scg(1) - gcg(1) ~= 0)
            cols = [0 0];
            rows = [Row_sweep(idx,1) Row_sweep(idx,2)];
        elseif  (scg(2) - gcg(2) ~= 0)
            cols = [gcg(1), gcg(1)];
            rows = [0 0];
        end
        [Wp_s, Gvis_best] = PC_NewAlg(gs, start_shape, Wp_hack(idx,3),Gvis, scg, gcg, GA, GSC, rows, cols, Row_sweep_dir(idx)); %segemented Wp
        Wp = [Wp; Wp_s];
        scg = gcg;
        Gvis = Gvis_best;
    end
    
    Wp(:, 1:2) = (Wp(:, 1:2) - 0.5)*gw;
    Wp_hack = (Wp_hack-0.5)*gw;
end