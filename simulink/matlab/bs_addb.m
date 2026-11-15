function h = bs_addb(src, dst, varargin)
% add_block that finds the library path itself when the one I guessed does not exist in your release
try
    h = add_block(src, dst, varargin{:}); return
catch
end
name = regexp(src, '[^/]+$', 'match', 'once');
libs = {'powerlib','powerlib_extras','electricdrivelib','sps_lib','powerlib_models','simscape_electrical'};
for k = 1:numel(libs)
    try, load_system(libs{k}); catch, continue, end
    hits = find_system(libs{k}, 'LookUnderMasks','none', 'FollowLinks','off', 'Name', name);
    if ~isempty(hits)
        fprintf('Using %s for "%s" (guessed path was not valid)\n', hits{1}, name);
        h = add_block(hits{1}, dst, varargin{:}); return
    end
end
error(['Cannot find a library block named "%s". In the library browser right-click the block > ' ...
       'Help/"Copy block path" (or add it by hand), and send me the path.'], name);
end
