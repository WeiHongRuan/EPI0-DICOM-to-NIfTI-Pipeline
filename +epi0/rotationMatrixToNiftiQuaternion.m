function [a, b, c, d] = rotationMatrixToNiftiQuaternion(R)
    % Convert a proper 3-by-3 rotation matrix to quaternion [a b c d].
    % The sign is chosen so a >= 0, as required by the NIfTI convention.

    traceValue = trace(R);

    if traceValue > 0
        scale = 2 * sqrt(traceValue + 1);
        a = 0.25 * scale;
        b = (R(3, 2) - R(2, 3)) / scale;
        c = (R(1, 3) - R(3, 1)) / scale;
        d = (R(2, 1) - R(1, 2)) / scale;

    elseif R(1, 1) > R(2, 2) && R(1, 1) > R(3, 3)
        scale = 2 * sqrt(1 + R(1, 1) - R(2, 2) - R(3, 3));
        a = (R(3, 2) - R(2, 3)) / scale;
        b = 0.25 * scale;
        c = (R(1, 2) + R(2, 1)) / scale;
        d = (R(1, 3) + R(3, 1)) / scale;

    elseif R(2, 2) > R(3, 3)
        scale = 2 * sqrt(1 + R(2, 2) - R(1, 1) - R(3, 3));
        a = (R(1, 3) - R(3, 1)) / scale;
        b = (R(1, 2) + R(2, 1)) / scale;
        c = 0.25 * scale;
        d = (R(2, 3) + R(3, 2)) / scale;

    else
        scale = 2 * sqrt(1 + R(3, 3) - R(1, 1) - R(2, 2));
        a = (R(2, 1) - R(1, 2)) / scale;
        b = (R(1, 3) + R(3, 1)) / scale;
        c = (R(2, 3) + R(3, 2)) / scale;
        d = 0.25 * scale;
    end

    quaternionNorm = sqrt(a*a + b*b + c*c + d*d);
    a = a / quaternionNorm;
    b = b / quaternionNorm;
    c = c / quaternionNorm;
    d = d / quaternionNorm;

    if a < 0
        a = -a;
        b = -b;
        c = -c;
        d = -d;
    end
end
