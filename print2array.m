%PRINT2ARRAY  Exports a figure to an image array
%
% Examples:
%   A = print2array
%   A = print2array(figure_handle)
%   A = print2array(figure_handle, resolution)
%   A = print2array(figure_handle, resolution, renderer)
%   [A bcol] = print2array(...)
%
% This function outputs a bitmap image of the given figure, at the desired
% resolution.
%
% If renderer is '-painters' then ghostcript needs to be installed. This
% can be downloaded from: http://www.ghostscript.com
%
% IN:
%   figure_handle - The handle of the figure to be exported. Default: gcf.
%   resolution - Resolution of the output, as a factor of screen
%                resolution. Default: 1.
%   renderer - string containing the renderer paramater to be passed to
%              print. Default: '-opengl'.
%
% OUT:
%   A - MxNx3 uint8 image of the figure.
%   bcol - 1x3 uint8 vector of the background color

% Copyright (C) Oliver Woodford 2008-2011

% 5/9/2011 Set EraseModes to normal when using opengl or zbuffer renderers.
% Thanks to Pawel Kocieniewski for reporting the issue.

% 21/9/2011 Bug fix: unit8 -> uint8!
% Thanks to Tobias Lamour for reporting the issue.

function [A bcol] = print2array(fig, res, renderer)
% Generate default input arguments, if needed
if nargin < 2
    res = 1;
    if nargin < 1
        fig = gcf;
    end
end
% Warn if output is large
old_mode = get(fig, 'Units');
set(fig, 'Units', 'pixels');
px = get(fig, 'Position');
set(fig, 'Units', old_mode);
npx = prod(px(3:4)*res)/1e6;
if npx > 30
    % 30M pixels or larger!
    warning('MATLAB:LargeImage', 'print2array generating a %.1fM pixel image. This could be slow and might also cause memory problems.', npx);
end
% Retrieve the background colour
bcol = get(fig, 'Color');
% Set the resolution parameter
res_str = ['-r' num2str(ceil(get(0, 'ScreenPixelsPerInch')*res))];
% Generate temporary file name
tmp_nam = [tempname '.tif'];
if nargin > 2 && strcmp(renderer, '-painters')
    % Print to eps file
    tmp_eps = [tempname '.eps'];
    print2eps(tmp_eps, fig, renderer, '-loose');
    try
        % Export to tiff using ghostscript
        ghostscript(['-dEPSCrop -q -dNOPAUSE -dBATCH ' res_str ' -sDEVICE=tiff24nc -sOutputFile="' tmp_nam '" "' tmp_eps '"']);
    catch
        % Delete the intermediate file
        delete(tmp_eps);
        rethrow(lasterror);
    end
    % Delete the intermediate file
    delete(tmp_eps);
    % Read in the generated bitmap
    A = imread(tmp_nam);
    % Delete the temporary bitmap file
    delete(tmp_nam);
    % Set border pixels to the correct colour
    if isequal(bcol, 'none')
        bcol = [];
    elseif isequal(bcol, [1 1 1])
        bcol = uint8([255 255 255]);
    else
        for l = 1:size(A, 2)
            if ~all(reshape(A(:,l,:) == 255, [], 1))
                break;
            end
        end
        for r = size(A, 2):-1:l
            if ~all(reshape(A(:,r,:) == 255, [], 1))
                break;
            end
        end
        for t = 1:size(A, 1)
            if ~all(reshape(A(t,:,:) == 255, [], 1))
                break;
            end
        end
        for b = size(A, 1):-1:t
            if ~all(reshape(A(b,:,:) == 255, [], 1))
                break;
            end
        end
        bcol = median([reshape(A(:,[l r],:), [], size(A, 3)); reshape(A(:,[t b],:), [], size(A, 3))], 1);
        for c = 1:size(A, 3)
            A(:,[1:l-1, r+1:end],c) = bcol(c);
            A([1:t-1, b+1:end],:,c) = bcol(c);
        end
    end
else
    if nargin < 3
        renderer = '-opengl';
    end
    % Change the EraseMode property of all animated graphics objects
    % in the current figure to 'normal'
    hidden_state = get(0, 'showhiddenhandles');
    set(0, 'showhiddenhandles', 'on');
    erase_handles = findobj(fig, '-property', 'erasemode', '-not', 'erasemode', 'normal');
    set(0, 'showhiddenhandles', hidden_state);
    if ~isempty(erase_handles)
        erase_modes = get(erase_handles, {'erasemode'});
    end
    % Set paper size
    old_mode = get(fig, 'PaperPositionMode');
    set(fig, 'PaperPositionMode', 'auto');
    err = false;
    try
        try
            % Try hardcopy first - undocumented MATLAB function!
            A = hardcopy(fig, ['-D' renderer(2:end)], res_str);
        catch
            % Print to tiff file
            print(fig, renderer, res_str, '-dtiff', tmp_nam);
            % Read in the printed file
            A = imread(tmp_nam);
            % Delete the temporary file
            delete(tmp_nam);
        end
    catch ex
        err = true;
    end
    % Reset paper size
    set(fig, 'PaperPositionMode', old_mode);
    % Reset the EraseModes
    if ~isempty(erase_handles)
        set(erase_handles, {'erasemode'}, erase_modes);
    end
    if err
        rethrow(ex);
    end
    % Set the background color
    if isequal(bcol, 'none')
        bcol = [];
    else
        bcol = bcol * 255;
        if isequal(bcol, round(bcol))
            bcol = uint8(bcol);
        else
            bcol = squeeze(A(1,1,:));
        end
    end
end
% Check the output size is correct
if isequal(res, round(res))
    px = [px([4 3])*res 3];
    if ~isequal(size(A), px)
        % Correct the output size
        A = A(1:min(end,px(1)),1:min(end,px(2)),:);
    end
end
return
