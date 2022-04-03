function [Matriz_pared_manual,posiciones_pared] = ObtenerMatrizParedCircular(Desp_X, Desp_Y, distancias_angulares, radio) 
    posiciones_pared=[];
    Desp_X_pared=Desp_Y;
    Desp_Y_pared=Desp_X;
    %% OBTENEMOS LOS PUNTOS XY DEL SISTEMA DE REPRESENTACIÓN DE LAS ESQUINAS 
    for ang=1:400
        ang_rad=ang*0.9*pi/180;
        xp=radio*cos(ang_rad)+Desp_X_pared;
        yp=radio*sin(ang_rad)+Desp_Y_pared;
        [~,position]=min(abs(distancias_angulares(1,:)-sqrt(xp^2+yp^2))); % Obtener valor del array más cercano al valor medido
        posiciones_pared=[posiciones_pared position];
    end
    
    %% HAYAMOS LA INTERSECCIÓN ENTRE LOS 1200 PUNTOS DE CADA ÁNGULO Y LAS LINEAS QUE UNEN LAS ESQUINAS
    Matriz_pared_manual=zeros(400,1200);
    for ang=1:400
        Matriz_pared_manual(ang,posiciones_pared(1,ang):end)=255;
    end
end
