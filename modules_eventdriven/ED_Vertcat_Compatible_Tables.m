function [Result, Report] = ED_Vertcat_Compatible_Tables(Tables, Context)
%ED_VERTCAT_COMPATIBLE_TABLES Concatenate additive result-table schemas.
%
% Completed checkpoints can legitimately predate newly added diagnostic
% columns while retaining the same scientific simulation fingerprint. This
% helper preserves every existing value, creates missing columns from a
% matching prototype, and orders all variables before vertical concatenation.

    if nargin < 2 || isempty(Context)
        Context = 'result tables';
    end
    if ~iscell(Tables)
        error('ED:InvalidTableCellArray', ...
            'Tables must be supplied as a cell array.');
    end

    keep = cellfun(@(x) istable(x) && ~isempty(x), Tables);
    Tables = Tables(keep);
    Report = Empty_Report(numel(Tables));
    if isempty(Tables)
        Result = table();
        return;
    end

    variable_names = Tables{1}.Properties.VariableNames;
    for table_idx = 2:numel(Tables)
        names = Tables{table_idx}.Properties.VariableNames;
        variable_names = [variable_names, ...
            setdiff(names, variable_names, 'stable')]; %#ok<AGROW>
    end

    prototypes = cell(size(variable_names));
    for variable_idx = 1:numel(variable_names)
        name = variable_names{variable_idx};
        for table_idx = 1:numel(Tables)
            if ismember(name, ...
                    Tables{table_idx}.Properties.VariableNames)
                prototypes{variable_idx} = Tables{table_idx}.(name);
                break;
            end
        end
    end

    normalized = cell(size(Tables));
    missing_union = cell(1, 0);
    aligned_count = 0;
    backfilled_rows = 0;
    for table_idx = 1:numel(Tables)
        T = Tables{table_idx};
        present = T.Properties.VariableNames;
        missing_names = setdiff(variable_names, present, 'stable');
        if ~isempty(missing_names)
            aligned_count = aligned_count + 1;
            backfilled_rows = backfilled_rows + height(T);
            missing_union = [missing_union, ...
                setdiff(missing_names, missing_union, 'stable')]; %#ok<AGROW>
        end

        for variable_idx = 1:numel(variable_names)
            name = variable_names{variable_idx};
            prototype = prototypes{variable_idx};
            if ~ismember(name, present)
                T.(name) = Missing_Like(prototype, height(T));
            else
                Verify_Compatible_Variable( ...
                    T.(name), prototype, name, Context);
            end
        end
        normalized{table_idx} = T(:, variable_names);
    end

    Result = vertcat(normalized{:});
    Report.InputTableCount = numel(Tables);
    Report.AlignedTableCount = aligned_count;
    Report.BackfilledRowCount = backfilled_rows;
    Report.MissingVariableNames = string(missing_union);

    if aligned_count > 0
        warning('ED:TableSchemaAligned', ...
            ['%s: aligned %d of %d result tables containing additive ' ...
             'schema differences. %d row(s) were backfilled for %d ' ...
             'variable(s): %s. Missing floating-point values are NaN; ' ...
             'strings are missing; logical values are false.'], ...
            char(string(Context)), aligned_count, numel(Tables), ...
            backfilled_rows, numel(missing_union), ...
            Short_Name_List(missing_union));
    end
end

function Report = Empty_Report(input_count)
    Report = struct();
    Report.InputTableCount = input_count;
    Report.AlignedTableCount = 0;
    Report.BackfilledRowCount = 0;
    Report.MissingVariableNames = strings(1, 0);
end

function value = Missing_Like(prototype, row_count)
    dimensions = size(prototype);
    dimensions(1) = row_count;

    if isnumeric(prototype)
        if isfloat(prototype)
            value = nan(dimensions, 'like', prototype);
        else
            value = zeros(dimensions, 'like', prototype);
        end
    elseif islogical(prototype)
        value = false(dimensions);
    elseif isstring(prototype)
        value = strings(dimensions);
        value(:) = missing;
    elseif iscell(prototype)
        value = cell(dimensions);
    elseif ischar(prototype)
        value = repmat(' ', dimensions);
    elseif isdatetime(prototype)
        value = NaT(dimensions);
        if ~isempty(prototype.TimeZone)
            value.TimeZone = prototype.TimeZone;
        end
    elseif isduration(prototype)
        value = seconds(nan(dimensions));
        value.Format = prototype.Format;
    else
        error('ED:UnsupportedTableVariableType', ...
            ['Cannot backfill a result-table variable of class %s. ' ...
             'Rerun the incompatible checkpoint or extend Missing_Like.'], ...
            class(prototype));
    end
end

function Verify_Compatible_Variable(value, prototype, name, context)
    if ~strcmp(class(value), class(prototype))
        error('ED:IncompatibleTableVariableType', ...
            ['%s: variable %s has incompatible classes %s and %s. ' ...
             'This is not an additive checkpoint-schema change.'], ...
            char(string(context)), name, ...
            class(prototype), class(value));
    end

    value_size = size(value);
    prototype_size = size(prototype);
    value_size(1) = 1;
    prototype_size(1) = 1;
    if ~isequal(value_size, prototype_size)
        error('ED:IncompatibleTableVariableSize', ...
            ['%s: variable %s has incompatible per-row sizes. ' ...
             'This is not an additive checkpoint-schema change.'], ...
            char(string(context)), name);
    end
end

function text = Short_Name_List(names)
    max_names = 10;
    if isempty(names)
        text = 'none';
        return;
    end
    shown = names(1:min(max_names, numel(names)));
    text = strjoin(shown, ', ');
    if numel(names) > max_names
        text = sprintf('%s, ... (+%d more)', ...
            text, numel(names) - max_names);
    end
end
