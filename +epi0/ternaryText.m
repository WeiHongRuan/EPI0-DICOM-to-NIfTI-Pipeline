function text = ternaryText(condition, trueText, falseText)
%TERNARYTEXT 簡單的條件文字選擇。

    if condition
        text = trueText;
    else
        text = falseText;
    end
end
