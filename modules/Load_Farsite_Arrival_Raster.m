function [X, Y, A, meta] = Load_Farsite_Arrival_Raster(SimParams)
%LOAD_FARSITE_ARRIVAL_RASTER Load FARSITE arrival time raster in minutes.

    base_dir = Get_Field_Or_Default(SimParams, 'Farsite_Output_Dir', 'farsite_output');
    fmt = Get_Field_Or_Default(SimParams, 'Farsite_Arrival_Format', 'asc');

    switch lower(fmt)
        case 'asc'
            default_asc_file = Get_Default_Farsite_Asc_File(base_dir);
            fname = fullfile(base_dir, Get_Field_Or_Default(SimParams, ...
                'Farsite_Arrival_Asc_File', default_asc_file));
            [A, meta] = Read_Ascii_Grid(fname);
            meta.Source_File = fname;
            x = meta.xllcorner + (0:meta.ncols-1) * meta.cellsize;
            y = meta.yllcorner + (0:meta.nrows-1) * meta.cellsize;
            [X, Y] = meshgrid(x, y);

        case 'csv_matrix'
            a_file = fullfile(base_dir, Get_Field_Or_Default(SimParams, ...
                'Farsite_Arrival_Csv_File', 'farsite_arrival_time.csv'));
            x_file = fullfile(base_dir, Get_Field_Or_Default(SimParams, ...
                'Farsite_Arrival_X_Csv_File', 'farsite_arrival_x.csv'));
            y_file = fullfile(base_dir, Get_Field_Or_Default(SimParams, ...
                'Farsite_Arrival_Y_Csv_File', 'farsite_arrival_y.csv'));

            A = readmatrix(a_file);
            x = readmatrix(x_file);
            y = readmatrix(y_file);
            x = x(:).';
            y = y(:);
            [X, Y] = meshgrid(x, y);

            meta = struct();
            meta.nrows = size(A, 1);
            meta.ncols = size(A, 2);
            meta.xllcorner = min(x);
            meta.yllcorner = min(y);
            if numel(x) > 1
                meta.cellsize = median(diff(x));
            else
                meta.cellsize = NaN;
            end
            meta.NODATA = NaN;
            meta.Source_File = a_file;

        otherwise
            error('Unsupported Farsite_Arrival_Format: %s', fmt);
    end

    A(A < 0) = NaN;
    if all(isnan(A(:)))
        error('FARSITE arrival raster contains only NaN values.');
    end
end

function fname = Get_Default_Farsite_Asc_File(base_dir)
    preferred = 'farsite_arrival_time_260611.asc';
    legacy = 'farsite_arrival_time.asc';

    if exist(fullfile(base_dir, preferred), 'file')
        fname = preferred;
    elseif exist(fullfile(base_dir, legacy), 'file')
        fname = legacy;
    else
        fname = preferred;
    end
end

function [A, meta] = Read_Ascii_Grid(fname)
    fid = fopen(fname, 'r');
    if fid == -1
        error('Cannot open FARSITE ASCII grid file: %s', fname);
    end

    hdr = cell(6, 1);
    for k = 1:6
        hdr{k} = strtrim(fgetl(fid));
    end

    meta = struct();
    meta.ncols = sscanf(hdr{1}, 'ncols %f');
    meta.nrows = sscanf(hdr{2}, 'nrows %f');
    meta.xllcorner = sscanf(hdr{3}, 'xllcorner %f');
    if isempty(meta.xllcorner)
        meta.xllcorner = sscanf(hdr{3}, 'xllcenter %f');
    end
    meta.yllcorner = sscanf(hdr{4}, 'yllcorner %f');
    if isempty(meta.yllcorner)
        meta.yllcorner = sscanf(hdr{4}, 'yllcenter %f');
    end
    meta.cellsize = sscanf(hdr{5}, 'cellsize %f');
    meta.NODATA = sscanf(hdr{6}, 'NODATA_value %f');

    A = fscanf(fid, '%f', [meta.ncols, meta.nrows])';
    fclose(fid);
    A(A == meta.NODATA) = NaN;
end

function val = Get_Field_Or_Default(S, field_name, default_val)
    if isfield(S, field_name) && ~isempty(S.(field_name))
        val = S.(field_name);
    else
        val = default_val;
    end
end
