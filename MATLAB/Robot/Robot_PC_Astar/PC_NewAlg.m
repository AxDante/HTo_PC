function [Wp_s, Gvis_best] = PC_NewAlg(gs, Gobs, Wp, Gvis, scg, gcg, GA, GSC, rows, cols)
    
    ccg = scg;   % Current Center Grid
    cost = 0;
    cost_best = 1000;
    Wp_best = [];
    
    shape = 2;
    Wp = [scg(1) scg(2)];
    width = 0;
    
    rows_init = rows;
    
    while (cost_best == 1000 && width < 6) 
    
        if mod(width,2) == 1
            rows = [rows(1)-ceil(width/2) rows(2)];
        elseif mod(width,2) == 0
            rows = [rows(1) rows(2)+width/2];
        end
        disp(['Begin navigation from (',num2str(scg(1)), ', ', num2str(scg(2)), ') to (', num2str(gcg(1)), ', ', num2str(gcg(2)) ,').']);
        [Wp_best, Wp, cost_best, cost, Gvis_best, Gvis] = recurse_cost(gs, ccg, gcg, GA, GSC, cost, cost_best, Wp, Wp_best, shape, [0 0], rows, cols, Gvis, Gvis, rows_init);
        Wp_s = Wp_best;
        disp(['End navigation from (',num2str(scg(1)), ', ', num2str(scg(2)), ') to (', num2str(gcg(1)), ', ', num2str(gcg(2)) ,').' ...
            , ' cost = ', num2str(cost_best)]);
        disp(['best Wp:']);
        Wp_best
        
        width = width +1;
    end
    
end