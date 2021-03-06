% function that comptues statistics of face detection initialization
function [] = face_det_stat()
	saveDir = 'matfiles/'; 	
	
% 	[TR_images, TR_face_sizes, TR_gt_landmarks, TR_myShape_pRigid, TR_myShape_pNonRigid, ~] = Collect_training_images(n1, n2) ; 
	
	gtParamDir = 'TR_params/';
	load([gtParamDir 'TR_face_size.mat']); 
	load([gtParamDir 'TR_gt_landmarks.mat']); 
	load([gtParamDir 'TR_detections.mat']);		% detected bounding boxes 
	load([gtParamDir 'TR_myShape_pRigid.mat']);
	load([gtParamDir 'TR_myShape_pNonRigid.mat']);
		
	KNonrigid = size(TR_myShape_pNonRigid, 2);	
	n = size(TR_myShape_pNonRigid, 1);		% number of images
	
%% compute statistics of 3D shape parameters from all images of Helen and LFPW training dataset
	% nonrigid parameters
	mean_nonrigid_params = mean(TR_myShape_pNonRigid, 1);
	var_nonrigid_params = var(TR_myShape_pNonRigid, 1);
	std_nonrigid_params = sqrt(var_nonrigid_params); 
	
	% rotation angle
	mean_rotation_angle = mean(TR_myShape_pRigid(:, 4));
	var_rotation_angle = var(TR_myShape_pRigid(:, 4));
	std_rotation_angle= sqrt(var_rotation_angle ); 
	
	% scale and translation
	for gg = 1:n
		gt_landmark = TR_gt_landmarks{gg};
		face_size = TR_face_size{gg};
		bb_gt(gg, :) =  [min(gt_landmark(:,1)), min(gt_landmark(:, 2)), max(gt_landmark(:,1)) - min(gt_landmark(:,1)), max(gt_landmark(:,2)) - min(gt_landmark(:,2))]; 
		bb_detection(gg, :) = TR_detections{gg}; 
		delta_translation(gg, 1) = (bb_detection(gg,1) - bb_gt(gg, 1)) / face_size; 
		delta_translation(gg, 2) = (bb_detection(gg, 2) - bb_gt(gg, 2)) / face_size; 
		delta_scale(gg, 1)  = ((bb_detection(gg, 3) / bb_gt(gg, 3)) + (bb_detection(gg, 4) / bb_gt(gg, 4)) )	/2;
	end
	
	mean_delta_translation = mean(delta_translation);
	var_delta_translation = var(delta_translation);
	std_delta_translation = sqrt(var_delta_translation);
	
	mean_delta_scale = mean(delta_scale);
	var_delta_scale = var(delta_scale);
	std_delta_scale = sqrt(var_delta_scale); 
	
	version = 'SM_1';
	save([saveDir 'fd_stat_SM.mat'], 'mean_delta_scale', 'var_delta_scale', 'std_delta_scale', ...
		'mean_delta_translation', 'var_delta_translation', 'std_delta_translation', ...
		'mean_rotation_angle', 'var_rotation_angle', 'std_rotation_angle', ...
		'mean_nonrigid_params', 'var_nonrigid_params', 'std_nonrigid_params', 'version');

end

	