function pos = Get_Large_Figure_Position(target_w, target_h)
%GET_LARGE_FIGURE_POSITION Return a screen-aware large figure position.
%
% The plotting routines in this simulator often combine maps, legends, and
% multiple metric panels. MATLAB's default figure size is too small for that
% content, so this helper gives each figure a readable default while avoiding
% windows that are larger than the current screen.

    if nargin < 1 || isempty(target_w)
        target_w = 1600;
    end
    if nargin < 2 || isempty(target_h)
        target_h = 900;
    end

    screen = get(0, 'ScreenSize');
    max_w = max(900, screen(3) - 100);
    max_h = max(650, screen(4) - 160);

    w = min(target_w, max_w);
    h = min(target_h, max_h);
    x = max(20, screen(1) + (screen(3) - w) / 2);
    y = max(40, screen(2) + (screen(4) - h) / 2);

    pos = round([x y w h]);
end
