function out_str = sanitize(in_str, str_case)
    if ~exist('str_case', 'var')
        str_case = 'snake';
    end
    stripped = char(join(string(regexp(in_str, '[\w\s]+', 'match'))));
    words = regexp(stripped, '\w+', 'match');
    switch lower(str_case)
        case 'lower'
            out_str = lower(join(string(words), ''));
        case 'upper'
            out_str = upper(join(string(words), ''));
        case 'same'
            out_str = join(string(words), '');
        case 'snake'
            out_str = lower(join(string(words), '_'));
        case 'camel'
            out_str = join(string(cellfun(@(x)[upper(x(1)) lower(x(2:end))],words, 'UniformOutput', false)), '');
            out_str{1}(1) = lower(out_str{1}(1));
        case 'pascal'
            out_str = join(string(cellfun(@(x)[upper(x(1)) lower(x(2:end))],words, 'UniformOutput', false)), '');
        case 'cobra'
            out_str = join(string(cellfun(@(x)[upper(x(1)) lower(x(2:end))],words, 'UniformOutput', false)), '_');
        case 'title'
            words = regexp(strrep(stripped,"_"," "), '\w+', 'match');
            words = string(cellfun(@(x)[upper(x(1)) lower(x(2:end))],words, 'UniformOutput', false));
            lowercase_words = ["a","an","and","for","in","of","the"];
            for i = 1:length(words)
                if ismember(words(i), lowercase_words)
                    words(i) = lower(words(i));
                end
            end
            out_str = join(words, " ");
        case 'sentence'
            words = regexp(strrep(stripped,"_"," "), '\w+', 'match');
            first_word = char(words(1));
            words(1) = string([upper(first_word(1)), lower(first_word(2:end))]);
            
            out_str = join(words, ' ');
        otherwise
            error('Unrecognized case type %s', str_case);
    end
    out_str = char(out_str);
end
        
    