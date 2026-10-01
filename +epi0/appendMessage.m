function output = appendMessage(existingMessage, newMessage)
%APPENDMESSAGE 將多個處理訊息合併到同一欄位。

    if isempty(existingMessage)
        output = newMessage;
    elseif isempty(newMessage)
        output = existingMessage;
    else
        output = [existingMessage ' | ' newMessage];
    end
end
