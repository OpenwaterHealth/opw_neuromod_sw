function uuid = get_uuid(n)
    arguments
        n (1,1) double {mustBeInteger, mustBePositive} = 8
    end
    uuid = dec2hex(round(rand*(2^(4*n))), n);
end            