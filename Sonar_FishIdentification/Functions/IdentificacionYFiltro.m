function [N_peces,ID_peces,centroids_r,datos_360_objetos]=IdentificacionYFiltro(angle,Matriz_datos_360_intensidades,Matriz_pared_manual,conn,umbral_conectividad,distancia_ruido,lim_cant_datos,lim_inf_intensidad,lim_min_cant_pez,distancia_puntos,Paso_motor_rad,vuelta)   
    % Operación entre matrices para eliminar fronteras
    if vuelta==1
        datos_360_objetos=Matriz_datos_360_intensidades-Matriz_pared_manual(1:angle,:);
    else
        datos_360_objetos=Matriz_datos_360_intensidades-Matriz_pared_manual;
    end
    datos_360_objetos(datos_360_objetos<lim_inf_intensidad)=0;
    
    XY_Centroids_ID=[];
    ID_peces=[];
    
    % Clustering
    if vuelta==1
        datos_360_objetos_bin(1:angle,:)=bwareaopen(datos_360_objetos(1:angle,:),umbral_conectividad,conn); %elimina todos los conjuntos de pixeles compuestos por menos de x elementos
    else
        datos_360_objetos_bin=bwareaopen(datos_360_objetos,umbral_conectividad,conn); %elimina todos los conjuntos de pixeles compuestos por menos de x elementos
    end
    L_r=bwlabel(datos_360_objetos_bin, conn); %etiqueta todos los pixeles distintos de cero
    CC = bwconncomp(L_r, conn);
    s_r=regionprops(L_r,'centroid'); %calcula el centroide de cada grupo de pixeles, obtenidos en columnas y filas
    centroids_r = cat(1, s_r.Centroid);
      
    if CC.NumObjects>0
        for j=1:CC.NumObjects
            [pixeles,~]=size(CC.PixelIdxList{1,j});
            x_cent = distancia_puntos*centroids_r(j,1)*sin(centroids_r(j,2)*Paso_motor_rad);
            y_cent = distancia_puntos*centroids_r(j,1)*cos(centroids_r(j,2)*Paso_motor_rad);
            XY_Centroids_ID=[XY_Centroids_ID ;[x_cent y_cent sqrt(x_cent^2+(y_cent-12.1875)^2)]];

            if XY_Centroids_ID(j,3)>=distancia_ruido
                if pixeles>lim_cant_datos %ruido central
                    datos_360_objetos(CC.PixelIdxList{1,j})=0;
                elseif pixeles>lim_min_cant_pez
                    ID_peces=[ID_peces;j];
                else % ruido minusculo
                    datos_360_objetos(CC.PixelIdxList{1,j})=0;
                end
            end
        end
    end
    
    [m,~]=size(ID_peces);
    N_peces=m;
end
