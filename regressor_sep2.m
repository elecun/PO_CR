%function [] = regressor_sep(SIFT_scale, Kpi, T, ridge_param, learning_rate, smallsize)
clear;
Kpi = 10;
T = 1;
ridge_param = 0;
learning_rate = 0.5;
smallsize = 0;
SIFT_scale = 15; 

for learning_rate = 0.1 : 0.1 : 1
	%% initialization
	addpath('functions/');
	cd 'vlfeat-0.9.20/toolbox'
	vl_setup
	cd '../../'
	shapemodel = load('shape_model.mat');
	myShape = load('myShape.mat'); 
	myAppearance = load('myAppearance');
	fd_stat = load('fd_stat');
	shapemodel = shapemodel.shape;
	myShape = myShape.myShape;
	myAppearance = myAppearance.myAppearance;
	fd_stat = fd_stat.fd_stat;
	datasetDir = '../dataset/'; 
	testsetDir = '../test_data/'; 
	outputDir = 'IntermediateResult/'; 
	CLMDir = './';
	folder1 = [datasetDir 'helen/trainset/'];
	what1 = 'jpg';
	folder2 = [datasetDir 'lfpw/trainset/'];
	what2 = 'png';
	names1 = dir([folder1 '*.' what1]);
	names2 = dir([folder1 '*.pts']);
	names3 = dir([folder2 '*.' what2]);
	names4 = dir([folder2 '*.pts']);
	num_of_pts = 68;                                              % num of landmarks in the annotations
	P = eye(size(myAppearance.A,1)) - myAppearance.A * myAppearance.A'; 
	N = size(myAppearance.A, 1);				% number of SIFT features
	m = size(myAppearance.A, 2);                            % number of eigenvectors of myAppearance.A
	K = size(myShape.p, 2);                                      % number of eigenvectors of myShape.Q
	var = 0:0.02:0.9;
	n1 = length(names1);					     % 2000
	n2 = length(names3);					     % 811
	n = n1 + n2; 
	if smallsize == 1
		n1 = 15;
		n2 = 15;
		n = n1 + n2;
	end
	
	%% cascaded regression for only Helen and LFPW dataset
	p_mat = zeros(n, Kpi, K);
	delta_p_mat = zeros(n, Kpi, K);
	feat = zeros(n, Kpi, N);
	b_mat = zeros(n, Kpi, N);
	pt_pt_err = zeros(T, n);				       % stores pt-pt error for each image
	% initialize p_mat
	myShape_p = myShape.p;
	myShape_p(:, 4) = 0;	
	fd_stat_std = [fd_stat.std(1:4), zeros(1, K-4)];
	for gg = 1:n
		for k = 1 : Kpi
			p_mat(gg, k, :) = [myShape_p(gg, 1:4) , zeros(1, K-4)] + fd_stat_std .* rand(1, K)  - fd_stat_std / 2; 
		end
		pp(1, gg, :) = p_mat(gg, 1, :);
	end
	save([outputDir 'ppp/ppp_initial_S-' num2str(SIFT_scale) '_P-' num2str(Kpi) '_R-' num2str(ridge_param) '_L-' num2str(learning_rate) '.mat'], 'pp');
	p_mat2 = p_mat(n1+1:n1+n2, :, :);
	feat2 = zeros(n2, Kpi, N);
	b_mat2 = zeros(n2, Kpi, N);
	pt_pt_err2 = zeros(T, n2);	
		
	for t = 1 : T
		disp(['iteration is ' num2str(t)]);
		myShapeS0 = myShape.s0; 
		myShapeQ = myShape.Q; 
		A0P = myAppearance.A0' * P;  
		shapemodelS0 = shapemodel.s0; 
		
		%% parallel task - initialize perturbed shape parameters of image(gg), compute feature matrix
		disp( 'extracting features from Helen train dataset');
		parfor gg = 1 : n1
			p_mat_gg = p_mat(gg, :, :);		
			pts = read_shape([folder1 names2(gg).name], num_of_pts);                         % read ground truth landmarks
			input_image = imread([folder1 names1(gg).name]); 
			gt_landmark = (pts-1);
			gt_landmark = reshape(gt_landmark, 68, 2);

			% scale ground truth landmarks, image, shape parameters to mean face size
			[~,~,Tt] = procrustes(shapemodelS0, gt_landmark);        
			scl = 1/Tt.b;
			gt_landmark = gt_landmark*(1/scl); 
			input_image = imresize(input_image, (1/scl));
			for k = 1 : Kpi
				lm = myShapeS0 + myShapeQ(:, 2:end) * reshape(p_mat_gg(1, k, 2:end), 1, [])'; 
				lm = reshape(lm, 68, 2) * (1/scl);
				lm = lm * p_mat_gg(1, k, 1);				% scale
				Sfeat = SIFT_features(input_image, lm, SIFT_scale);
				feat(gg, k, :) = reshape(Sfeat, 1, []); 
				b_mat(gg, k, :) =  reshape(feat(gg, k, :), 1, []) - A0P;
			end
			p_mat(gg, :, :) = p_mat_gg;
		end   
		disp('extracting features from LFPW train dataset');
		parfor gg = 1:n2
			p_mat_gg = p_mat2(gg, :, :);		
			pts = read_shape([folder2 names4(gg).name], num_of_pts);  
			input_image = imread([folder2 names3(gg).name]); 	
			gt_landmark = (pts-1);
			gt_landmark = reshape(gt_landmark, 68, 2);

			% scale ground truth landmarks, image, shape parameters to mean face size
			[~,~,Tt] = procrustes(shapemodelS0, gt_landmark);        
			scl = 1/Tt.b;
			gt_landmark = gt_landmark*(1/scl); 
			input_image = imresize(input_image, (1/scl));
			for k = 1 : Kpi
				lm = myShapeS0 + myShapeQ(:, 2:end) * reshape(p_mat_gg(1, k, 2:end), 1, [])'; 
				lm = reshape(lm, 68, 2) * (1/scl);
				lm = lm * p_mat_gg(1, k, 1);				% scale
				Sfeat = SIFT_features(input_image, lm, SIFT_scale);
				feat2(gg, k, :) = reshape(Sfeat, 1, []); 
				b_mat2(gg, k, :) =  reshape(feat2(gg, k, :), 1, []) - A0P;
			end
			p_mat2(gg, :, :) = p_mat_gg; 
		end                       
		p_mat(n1+1:n1+n2, :, :) = p_mat2;
		b_mat(n1+1:n1+n2, :, :) = b_mat2;
		
		%% centralized task 
		disp( 'duplicating matrices and doing ridge regresstion');
		V = Kpi * ones(n);
		f = @(k) repmat(myShape.p(k,:), round(V(k)), 1);
		p_star_mat = cell2mat(arrayfun(f, (1:length(V))', 'UniformOutput', false));
		start = 1; 
		for g = 1 : n
		    p_star_mat_t(g, :, :) = p_star_mat(start : start + Kpi - 1, :);
		    start = start + Kpi;
		end
		delta_p_mat = p_star_mat_t - p_mat; 

		% ridge regression to compute Jp seperately
		Jp = zeros(N, K);
		for reg = 1 : N                                                                                             % compute beta_i
			Jp(reg, :) = ridge(reshape( b_mat(:, :, reg), [], 1), reshape(delta_p_mat, size(delta_p_mat,1) * size(delta_p_mat,2), size(delta_p_mat, 3)), ridge_param);
		end

		%% parallel task - update shape parameter p and compute pt-pt error
		disp('updating shape parameters for Helen train set and computing pt-pt error');
		Hessian = Jp' * Jp; 
		Risk = Hessian \ Jp'; 
		parfor gg = 1:n1
			% update p_mat
			p_mat_gg = p_mat(gg, :, :);
			for k = 1 : Kpi
				p_mat_gg(1, k, :) = (reshape(p_mat_gg(1, k, :), 1, K )' + learning_rate * Risk * reshape((b_mat(gg, k, :)), 1, N)')';
			end
			ppp(t, gg, :) = (p_mat_gg(1, 1, :));
			p_mat(gg, :, :) = p_mat_gg; 

			% compute pt-pt error
			pts = read_shape([folder1 names2(gg).name], num_of_pts);
			gt_landmark = (pts-1);
			gt_landmark = reshape(gt_landmark, 68, 2);
			[~,~,Tt] = procrustes(shapemodelS0, gt_landmark);        
			scl = 1/Tt.b;
			gt_landmark = gt_landmark*(1/scl); 
			face_size = (max(gt_landmark(:,1)) - min(gt_landmark(:,1)) + max(gt_landmark(:,2)) - min(gt_landmark(:,2)))/2;
			pt_pt_err1 = zeros(1, Kpi);
			for k = 1 : Kpi
				fitted_shape = myShapeS0 + myShapeQ * reshape(p_mat_gg(1, k, :), [], 1);
				pt_pt_err1(1, k) = mean(abs(fitted_shape - reshape(gt_landmark, [], 1))) / face_size;
			end
			pt_pt_err(t, gg) = sum(pt_pt_err1) / Kpi;
		end 
		disp('updating shape parameters for LFPW train set and computing pt-pt error');
		parfor gg = 1:n2
			% update p_mat
			p_mat_gg = p_mat2(gg, :, :);
			for k = 1 : Kpi
				p_mat_gg(1, k, :) = (reshape(p_mat_gg(1, k, :), 1, K )' + learning_rate * Risk * reshape((b_mat2(gg, k, :)), 1, N)')';
			end
			ppp(t, gg, :) = (p_mat_gg(1, 1, :));
			p_mat2(gg, :, :) = p_mat_gg; 

			% compute pt-pt error
			pts = read_shape([folder2 names4(gg).name], num_of_pts);
			gt_landmark = (pts-1);
			gt_landmark = reshape(gt_landmark, 68, 2);
			[~,~,Tt] = procrustes(shapemodelS0, gt_landmark);        
			scl = 1/Tt.b;
			gt_landmark = gt_landmark*(1/scl); 
			face_size = (max(gt_landmark(:,1)) - min(gt_landmark(:,1)) + max(gt_landmark(:,2)) - min(gt_landmark(:,2)))/2;
			pt_pt_err1 = zeros(1, Kpi);
			for k = 1 : Kpi
				fitted_shape = myShapeS0 + myShapeQ * reshape(p_mat_gg(1, k, :), [], 1);
				pt_pt_err1(1, k) = mean(abs(fitted_shape - reshape(gt_landmark, [], 1))) / face_size;
			end
			pt_pt_err2(t, gg) = sum(pt_pt_err1) / Kpi;
		end 
		p_mat(n1+1:n1+n2, :, :) = p_mat2;
		b_mat(n1+1:n1+n2, :, :) = b_mat2;
		pt_pt_err(t, n1+1:n1+n2) = pt_pt_err2(t, :); 
		
		pt_pt_err_all(t) = sum(pt_pt_err(t, :)) / n;
		
		%% cumulative curve
		cum_err = zeros(size(var));
		for ii = 1:length(cum_err)
			cum_err(ii) = length(find(pt_pt_err(t, :)<var(ii)))/length(pt_pt_err(t, :));
		end
		cum_err_full(t, :) = cum_err;

		%% save intermediate results per iteration
		disp( 'saving results to output directory for this iteratoin');
		save([outputDir 'pt_pt_err_all/pt_pt_err_all_i-' num2str(t) '_S-' num2str(SIFT_scale) '_P-' num2str(Kpi) '_R-' num2str(ridge_param) '_L-' num2str(learning_rate) '.mat'], 'pt_pt_err_all');
		save([outputDir 'b_mat/b_mat_i-' num2str(t) '_S-' num2str(SIFT_scale) '_P-' num2str(Kpi) '_R-' num2str(ridge_param) '_L-' num2str(learning_rate) '.mat'], 'b_mat');
		save([outputDir 'Risks/Risk_i-' num2str(t) '_S-' num2str(SIFT_scale) '_P-' num2str(Kpi) '_R-' num2str(ridge_param) '_L-' num2str(learning_rate) '.mat'], 'Risk');
		save([outputDir 'JPs/seperate/Jp_i-' num2str(t) '_S-' num2str(SIFT_scale) '_P-' num2str(Kpi) '_R-' num2str(ridge_param) '_L-' num2str(learning_rate) '.mat'], 'Jp');
		save([outputDir 'ppp/ppp_i-' num2str(t) '_S-' num2str(SIFT_scale) '_P-' num2str(Kpi) '_R-' num2str(ridge_param) '_L-' num2str(learning_rate) '.mat'], 'ppp');
		save([outputDir 'cum_err/cum_err_i-' num2str(t) '_S-' num2str(SIFT_scale) '_P-' num2str(Kpi) '_R-' num2str(ridge_param) '_L-' num2str(learning_rate) '.mat'], 'cum_err');		
	end 

	%% save result
	disp( 'finish all iterations in training. saving results')
	save([outputDir 'Jp.mat'], 'Jp');
	save([outputDir 'cum_err_full.mat'], 'cum_err_full');

	%% plot cumulative error curve
	% figure; hold on;
	% 
	% color = [ 0, 0, 0; 1, 0, 0; 1, 1, 0; 0, 1, 0; 0, 0, 1];
	% for t = 1 : T
	% 	plot(var, cum_err_full, 'Color', color(t,:), 'linewidth', 2); grid on;
	% end
	% xtick = 5*var;
	% ytick = 0:0.05:1;
	% set(gca, 'xtick', xtick);
	% set(gca, 'ytick', ytick);
	% ylabel('Percentage of Images', 'Interpreter','tex', 'fontsize', 15)
	% xlabel('Pt-Pt error normalized by face size', 'Interpreter','tex', 'fontsize', 13)
	% legend(['iteration' num2str(t)]);

	%% visualize iterations
% 	pp = load([outputDir 'ppp/ppp_initial_S-' num2str(SIFT_scale) '_P-' num2str(Kpi) '_R-' num2str(ridge_param) '_L-' num2str(learning_rate) '.mat']);
% 	pp = pp.pp;
% 	ppp = load([outputDir 'ppp/ppp_i-' num2str(T) '_S-' num2str(SIFT_scale) '_P-' num2str(Kpi) '_R-' num2str(ridge_param) '_L-' num2str(learning_rate) '.mat']);
% 	ppp = ppp.ppp;
% 	figure; hold on;
% 	for gg = 1:15
% 		lm0 = myShape.s0 + myShape.Q(:, 2:end) * reshape(pp(1, gg, 2:end), 1, [])';
% 		lm1 = myShape.s0 + myShape.Q(:, 2:end) * reshape(ppp(1, gg, 2:end), 1, [])';
% % 		lm2 = myShape.s0 + myShape.Q(:, 2:end) * reshape(ppp(2, gg, 2:end), 1, [])';
% % 		lm3 = myShape.s0 + myShape.Q(:, 2:end) * reshape(ppp(3, gg,  2:end), 1, [])';
% 		% lm4 = myShape.s0 + myShape.Q(:, 2:end) * reshape(ppp(4, gg,  2:end), 1, [])';
% 		% lm5 = myShape.s0 + myShape.Q(:, 2:end) * reshape(ppp(5, gg,  2:end), 1, [])';
% 		lm0 = reshape(lm0, [],2);
% 		lm1 = reshape(lm1, [],2);
% % 		lm2 = reshape(lm2, [],2);
% % 		lm3 = reshape(lm3, [],2);
% 		% lm4 = reshape(lm4, [],2);
% 		% lm5 = reshape(lm5, [],2);
% 		pts = read_shape([folder1 names2(gg).name], num_of_pts);                         
% 		gt_landmark = (pts-1);
% 		gt_landmark = reshape(gt_landmark, 68, 2);
% 		input_image = imread([folder1 names1(gg).name]); 
% 		[~,~,Tt] = procrustes(shapemodelS0, gt_landmark);        
% 		scl = 1/Tt.b;
% 		gt_landmark = gt_landmark*(1/scl); 
% 		input_image = imresize(input_image, (1/scl));
% 		subplot(5,6,gg);
% 		imagesc(input_image); colormap(gray); hold on;
% 		plot(lm0(:,1), lm0(:,2), 'Color', 'green');
% 		plot(lm1(:,1), lm1(:,2), 'Color', 'blue');
% % 		plot(lm2(:,1), lm2(:,2), 'Color', 'red');
% % 		plot(lm3(:,1), lm3(:,2), 'Color', 'blue');
% 		% plot(lm4(:,1), lm4(:,2), 'Color', 'yellow');
% 		% plot(lm5(:,1), lm5(:,2), 'Color', 'grey');
% 	end
% % 	
	
end


