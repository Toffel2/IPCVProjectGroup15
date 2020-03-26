clear variables;
close all;

banner = imread('../../UT_Logo_Black_EN.jpg');

%% Read the video
vid = VideoReader('../../video4.mp4');
output = VideoWriter('../../out.mp4','MPEG-4');
videoPlayer = vision.VideoPlayer();
vid.CurrentTime = 5;

%% Go through each frame and determine the goal post lines for each frame
%im=imread('test.jpg');
% figure;
% i=1;
% running=true;
% while hasFrame(vid)
%     frame=readFrame(vid);
%     b=rgb2gray(frame);            %bring frame to grayscale
%     b=b>200;                      %apply a threshold
%     BW=edge(b,'canny');           %edge detection of thresholded image
%     %line detection within certain orientation degrees
%     [H,T,R] = hough(BW,'Theta',-10:1:10); 
%     P  = houghpeaks(H,5,'threshold',ceil(0.5*max(H(:))));
%     lines = houghlines(BW,T,R,P,'MinLength',20);
%     %show the line in frame
%     imshow(frame), hold on
%     max_len = 0;
%     for k = 1:length(lines)
%        xy = [lines(k).point1; lines(k).point2];
%        plot(xy(:,1),xy(:,2),'LineWidth',2,'Color','green');
% 
%        % Plot beginnings and ends of lines
%        plot(xy(1,1),xy(1,2),'x','LineWidth',2,'Color','yellow');
%        plot(xy(2,1),xy(2,2),'x','LineWidth',2,'Color','red');
% 
%        % Determine the endpoints of the longest line segment
%        len = norm(lines(k).point1 - lines(k).point2);
%        if ( len > max_len)
%           max_len = len;
%           xy_long = xy;
%        end
%        drawnow 
%     end
% 
% end

%% initialize points of goal post of first frame
frame1 = read(vid, currentTime); 
frame1 = rgb2gray(frame1);
frame1 = frame1>200;
frame1_edge = edge(frame1,'canny');
[H,T,R] = hough(frame1_edge,'Theta',-10:1:10);
P  = houghpeaks(H,5,'threshold',ceil(0.5*max(H(:))));
lines = houghlines(frame1_edge,T,R,P,'MinLength',20);

for i = 1:length(lines)
    lines_length(i) = norm(lines(i).point1 - lines(i).point2);
end
i_longest_line = find(max(lines_length)); 
% consider goal post to be longest line detected
goal_post(1,:) = lines(i_longest_line).point1; 
goal_post(2,:) = lines(i_longest_line).point2;

%% find corners through templates
frame1 = rgb2gray(read(vid, currentTime));
cornerCrossingTemplate = imread('cropedLineCrossing.png');
cornerTemplate = imread('cropedCorner.png');
templateSize = size(cornerTemplate);
height = templateSize(2);
width = templateSize(1);

correlationOutput = normxcorr2(cornerTemplate,frame1);
% figure;
% imshow(correlationOutput);

[maxCorrValue, maxIndex] = maxk(abs(correlationOutput(:)),10);
[yPeak, xPeak] = ind2sub(size(correlationOutput),maxIndex);
corrPeaks = [xPeak, yPeak]; 
corr_offset = [(xPeak-size(cornerCrossingTemplate,2)) (yPeak-size(cornerCrossingTemplate,1))];
offset = corrPeaks-corr_offset;
corrPeaks = corrPeaks - offset./2;

% figure;
% imshow(frame1); hold on;
% for i = 1:1:length(corrPeaks)
%     if corrPeaks(i,:) ~= -1
%         out = insertMarker(frame1,corrPeaks,'x'); 
%          imshow(out);
%     drawnow
%     end
% end

%% create pointTracker and initialize

pointTracker = vision.PointTracker();
p_old = [goal_post; corrPeaks];
initialize(pointTracker,p_old,frame1);

%% loop through video and track points 
while hasFrame(vid)                             % Infinite loop to continuously detect the face
    frame = readFrame(vid);
    frame = rgb2gray(frame);                    % 
    [points,validity] = pointTracker(frame);    % track the points
    if max(points(2,1)<(points(1,1)+10), points(2,1)>(points(1,1)-10)) % if points are not above each other anymore
        frame_n = frame>200;
        frame_n_edge = edge(frame_n,'canny');
        [H,T,R] = hough(frame_n_edge,'Theta',-10:1:10);
        P  = houghpeaks(H,5,'threshold',ceil(0.5*max(H(:))));
        lines = houghlines(frame_n_edge,T,R,P,'MinLength',20);
        for i = 1:length(lines)
            lines_length(i) = norm(lines(i).point1 - lines(i).point2);
        end
        i_longest_line = find(max(lines_length));
        points_goal(1,:) = lines(i_longest_line).point1; 
        points_goal(2,:) = lines(i_longest_line).point2;
    end
%     if sum(validity)<1                   % if too many points are lost
        correlationOutput = normxcorr2(cornerTemplate,frame); 
        [maxCorrValue, maxIndex] = maxk(abs(correlationOutput(:)),10);
        [yPeak, xPeak] = ind2sub(size(correlationOutput),maxIndex);
        corrPeaks = [xPeak, yPeak]; 
        corr_offset = [(xPeak-size(cornerCrossingTemplate,2)) (yPeak-size(cornerCrossingTemplate,1))];
        offset = corrPeaks-corr_offset;
        corrPeaks = corrPeaks - offset./2;
%     end
    points = [points_goal; corrPeaks];
    setPoints(pointTracker,points); % set new points
    p_new  = points;   
    
    %estimate geometric transform
%     tform = estimateGeometricTransform(p_old,p_new,'projective');
%     banner_warp = imwarp(banner, tform);
%     imshow(banner_warp, []);
    
    %insert markers and play
    out = insertMarker(frame,points(validity, :),'x', 'Size', 10);
%     videoPlayer(out);
    step(videoPlayer, out);
    p_old = points;
end

release(videoPlayer);
