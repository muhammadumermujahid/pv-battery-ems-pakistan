function bs_setp(blk, varargin)
% set parameters one by one; report any that this release does not accept
for k = 1:2:numel(varargin)
    try, set_param(blk, varargin{k}, varargin{k+1});
    catch, warning('Parameter %s of %s not accepted - check it in the dialog.', varargin{k}, blk); end
end
end
