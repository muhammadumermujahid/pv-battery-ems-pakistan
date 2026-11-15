function bs_conn(sys, a, b)
% physical (SPS) connection; if the port is already used, warn so it can be wired by hand
try
    add_line(sys, a, b);
catch err
    warning('Could not auto-bs_conn two ports (%s). Wire this pair by hand.', err.message);
end
end
