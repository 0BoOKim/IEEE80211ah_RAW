function SimState = ED_Generate_Camera_Traffic( ...
    SimState, SimParams, new_alarm_ids, current_slot)
%ED_GENERATE_CAMERA_TRAFFIC Trigger fixed-sector cameras and enqueue video.
%
% A newly activated fire sensor starts the camera covering its sector. Any
% later sensor activation in that sector extends streaming until one stream
% duration after the latest activation.

    if ~SimState.ED_Camera.Enabled
        return;
    end

    cfg = SimParams.ED_Camera;
    duration_slots = max(1, round( ...
        cfg.StreamDurationSec / SimParams.T_slot));
    interval_slots = max(1, round( ...
        cfg.FrameIntervalSec / SimParams.T_slot));
    frame_bytes = round(cfg.FrameBytes);
    ap_pos = SimState.Node.Pos(SimParams.idx_AP(1), :);

    for alarm_id = new_alarm_ids(:).'
        relative = SimState.Node.Pos(alarm_id, :) - ap_pos;
        angle_deg = mod(atan2d(relative(2), relative(1)), 360);
        local_camera = floor(mod( ...
            angle_deg - SimState.ED_Camera.Sector_Boundary_Deg, 360) / ...
            SimState.ED_Camera.Sector_Width_Deg) + 1;
        local_camera = min(numel( ...
            SimState.ED_Camera.Node_IDs), local_camera);
        SimState.ED_Camera.Sensor_Trigger_Count(local_camera) = ...
            SimState.ED_Camera.Sensor_Trigger_Count(local_camera) + 1;

        new_end = current_slot + duration_slots - 1;
        old_end = SimState.ED_Camera.Active_Until_Slot(local_camera);
        if old_end < current_slot
            SimState.ED_Camera.Active_Intervals{local_camera}(end + 1, :) = ...
                [current_slot, new_end];
            SimState.ED_Camera.Active_Until_Slot(local_camera) = new_end;
            SimState.ED_Camera.Next_Frame_Slot(local_camera) = current_slot;
            SimState.ED_Camera.Activation_Count(local_camera) = ...
                SimState.ED_Camera.Activation_Count(local_camera) + 1;
        elseif new_end > old_end
            intervals = SimState.ED_Camera.Active_Intervals{local_camera};
            intervals(end, 2) = new_end;
            SimState.ED_Camera.Active_Intervals{local_camera} = intervals;
            SimState.ED_Camera.Active_Until_Slot(local_camera) = new_end;
            SimState.ED_Camera.Extension_Count(local_camera) = ...
                SimState.ED_Camera.Extension_Count(local_camera) + 1;
        end
    end

    for local_camera = 1:numel(SimState.ED_Camera.Node_IDs)
        if SimState.ED_Camera.Active_Until_Slot(local_camera) < current_slot
            SimState.ED_Camera.Next_Frame_Slot(local_camera) = inf;
            continue;
        end
        node_id = SimState.ED_Camera.Node_IDs(local_camera);
        while SimState.ED_Camera.Next_Frame_Slot(local_camera) <= current_slot
            [SimState.Node.TX_Buffer(node_id), SimState.GID] = ...
                ED_Enqueue_MPDU(SimState.Node.TX_Buffer(node_id), ...
                SimState.GID, frame_bytes, current_slot);
            SimState.n_enq(node_id) = SimState.n_enq(node_id) + 1;
            SimState.ED_Camera.Generated_Frames(local_camera) = ...
                SimState.ED_Camera.Generated_Frames(local_camera) + 1;
            SimState.ED_Camera.Generated_Bytes(local_camera) = ...
                SimState.ED_Camera.Generated_Bytes(local_camera) + frame_bytes;
            SimState.ED_Camera.Next_Frame_Slot(local_camera) = ...
                SimState.ED_Camera.Next_Frame_Slot(local_camera) + ...
                interval_slots;
        end
        % Keep the next nominal frame time even if it lies just beyond the
        % current active window. A later sensor trigger can extend the same
        % stream and make that frame due without introducing a discontinuity.
    end

    active_count = sum( ...
        SimState.ED_Camera.Active_Until_Slot >= current_slot);
    SimState.ED_Camera.Max_Concurrent = max( ...
        SimState.ED_Camera.Max_Concurrent, active_count);
end
