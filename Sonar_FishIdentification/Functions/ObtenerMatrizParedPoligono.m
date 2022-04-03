function [Matriz_pared_manual, XY_corners_T] = ObtenerMatrizParedPoligono(Corners_X,Corners_Y,Desp_X, Desp_Y, cerrado, theta, Posiciones_x, Posiciones_y, distancias_angulares)

    Desp_XY=[1 0 0 Desp_X; 0 1 0 Desp_Y; 0 0 1 0; 0 0 0 1];
    Rot_Z=[cos(theta) -sin(theta) 0 0; sin(theta) cos(theta) 0 0; 0 0 1 0; 0 0 0 1];

    O_T_WL=Rot_Z*Desp_XY; %matriz de transformación de local a UTM

    XY_corners=[Corners_X; Corners_Y; zeros(1,length(Corners_Y)); ones(1,length(Corners_Y))];
    XY_corners_T=O_T_WL*XY_corners;
    
    %% CALCULAMOS A QUÉ ANGULOS Y DISTANCIAS POLARES HACEN REFERENCIA LAS ESQUINAS
    [theta,rho] = cart2pol(XY_corners_T(1,:),XY_corners_T(2,:));
    angulos_corners=round(theta*200/pi);

    distancias_corners=[];
    [~,m]=size(angulos_corners);
    for z=1:m
        if angulos_corners(1,z)<100
            angulos_corners(1,z)=-angulos_corners(1,z)+100;
        else
            angulos_corners(1,z)=500-angulos_corners(1,z);
        end
        distancias_corners(z,1)=rho(1,z);
    end
    

    %% OBTENEMOS LOS PUNTOS XY DEL SISTEMA DE REPRESENTACIÓN DE LAS ESQUINAS 
    Puntos_XY_corners=[];
    for z=1:m
        [~,position]=min(abs(distancias_angulares-distancias_corners(z,1))); % Obtener valor del array más cercano al valor medido
        Puntos_XY_corners=[Puntos_XY_corners;[Posiciones_x(angulos_corners(1,z),position) Posiciones_y(angulos_corners(1,z),position)]];
    end

    
    %% HALLAMOS LA INTERSECCIÓN ENTRE LOS 1200 PUNTOS DE CADA ÁNGULO Y LAS LINEAS QUE UNEN LAS ESQUINAS
    % OBTENIENDO LAS DISTANCIAS (1:1200) A LA QUE SE ENCUENTRA LA PARED PARA CADA ÁNGULO
    Puntos_XY=[];
    Pared_med=[];
    Posiciones_finales=ones(400,1);
    saved=0;
    for z=1:m
        for h=1:400
            if cerrado ==1
               if z==m && cerrado == 1
                    [xi,yi] = polyxpoly([Puntos_XY_corners(z,1) Puntos_XY_corners(1,1)],[Puntos_XY_corners(z,2) Puntos_XY_corners(1,2)],[Posiciones_x(h,1) Posiciones_x(h,end)],[Posiciones_y(h,1) Posiciones_y(h,end)]);
               else
                    [xi,yi] = polyxpoly([Puntos_XY_corners(z,1) Puntos_XY_corners(z+1,1)],[Puntos_XY_corners(z,2) Puntos_XY_corners(z+1,2)],[Posiciones_x(h,1) Posiciones_x(h,end)],[Posiciones_y(h,1) Posiciones_y(h,end)]);
               end 
            else
                if z<m
                    [xi,yi] = polyxpoly([Puntos_XY_corners(z,1) Puntos_XY_corners(z+1,1)],[Puntos_XY_corners(z,2) Puntos_XY_corners(z+1,2)],[Posiciones_x(h,1) Posiciones_x(h,end)],[Posiciones_y(h,1) Posiciones_y(h,end)]);
                else
                    xi=[];
                    yi=[];
                end
            end

            if isempty(xi)==0
                Pared_med=[Pared_med ;(sqrt(xi^2+yi^2))];
                [~,position]=min(abs(distancias_angulares-sqrt(xi^2+yi^2))); % Obtener valor del array más cercano al valor medido
                Puntos_XY=[Puntos_XY;[Posiciones_x(angulos_corners(1,z),position) Posiciones_y(angulos_corners(1,z),position)]];
                if Posiciones_finales(h,1)==1
                    Posiciones_finales(h,1)=position;
                else
                    [~,col]=size(Posiciones_finales);
                    for j=1:col
                        if Posiciones_finales(h,j)~=1 && saved==0
                            Posiciones_finales(h,j+1)=position;
                            saved=1;
                        end
                    end
                    saved=0;
                end
            end
        end
    end
    
    %% FILTRAR ZONA DESEADA
    Matriz_pared_manual=ones(400,1200);
    if cerrado == 1
        for h=1:400
            Matriz_pared_manual(h,Posiciones_finales(h,1):end)=255;
        end
    else
        for h=1:400
            if h>min(angulos_corners) && h<max(angulos_corners)
                Matriz_pared_manual(h,1:min(Posiciones_finales(h,:)))=255;
                Matriz_pared_manual(h,max(Posiciones_finales(h,:)):end)=255;
            else
                Matriz_pared_manual(h,:)=255; 
            end
        end
    end
end

