function fstr = auto_tex(str)
    arguments 
        str (1,1) string
    end
    while true
        sub_text = regexp(str, "_[a-zA-Z0-9]+", 'match','once');
        if ismissing(sub_text)
            break
        end
        c = char(sub_text);
        rep_text = sprintf('_{%s}', c(2:end));
        str = strrep(str, sub_text, rep_text);
    end
    fstr = str;
end