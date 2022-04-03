 %{
REALIZADO POR: Alejandro Garrocho Cruz, Diciembre 2021

OBJETIVO: Este script consiste en representar los datos obtenidos con el 
sonar Ping360, con el objetivo de procesar los datos para llevar a cabo la 
estimación de la abundancia de peces.
%}

%% Abrir puerto de comunicación
global u;
u = udpport("byte", "IPV4");

%% Variables del muestreo
global ganancia
global distance
global Peces
global cambiaGain
global cambiaDist
cambiaGain=0;
cambiaDist=0;

Distancia=2.4; %En metros (radio)

distance=Distancia*1000;     % En mm
ganancia=0;         % 0=low, 1=normal, 2=high
duration=11;        % 5~500 us  (en la web pone 1~1000)
freq=750;           % Don't change recommended, it is only practical to use say 650kHz to 850kHz due to the narrow bandwidth of the acoustic receiver.
n_samples=1200;     % (FIJO) número de datos por cada angulo
transmit=1;         % (FIJO) 0=not transmit, 1=transmit when angle reached

Paso_motor_rad=pi/200; %0.9*pi/180
SoundSpeedWater=1.5; %en mm/us

% Cálculo de los valores que deben ser añadidos en el mensaje
time_to_return=distance/SoundSpeedWater*2;
time_interval=time_to_return/n_samples; %en us       time_interval=25ns*sample_period
sample_period=round(time_interval/0.025);
distancia_puntos=distance/n_samples;

if sample_period<80
    sample_period=80;
    time_interval=0.025*sample_period; %en us       time_interval=25ns*sample_period
    time_to_return=time_interval*n_samples;
    distance=SoundSpeedWater*(time_to_return/2); %distance en mm
    distancia_puntos=distance/n_samples;
elseif sample_period>39999
    sample_period=39999;
    time_interval=0.025*sample_period; %en us       time_interval=25ns*sample_period
    time_to_return=time_interval*n_samples;
    distance=SoundSpeedWater*(time_to_return/2); %distance en mm
    distancia_puntos=distance/n_samples;
end

%% Se crea la figura donde se representarán los datos y el mensaje para el sonar
figura=Grafica_Sonar360_v2(distance, ganancia);
[mensaje2601, sum_parcial]=CrearMensajeSonar360_TR(duration, sample_period, freq, n_samples, ganancia, transmit);

%% Se calculan las posiciones X,Y y distancia de cada punto representado
i=1:n_samples;
vuelta=0;
Posiciones_x=[];
Posiciones_y=[];

for HeadAngle=1:400
    x = distancia_puntos*i*sin(HeadAngle*Paso_motor_rad);
    Posiciones_x=[Posiciones_x ; x];
    y = distancia_puntos*i*cos(HeadAngle*Paso_motor_rad);
    Posiciones_y=[Posiciones_y ; y];
end
distancias_angulares=sqrt(x.^2+y.^2);

%% Se utiliza el filtro frontera si el muestreo contiene datos de límites del entorno
% Variables de los límites del entorno (frontera circular)
radio=1900; % en mm
Desp_X=0;
Desp_Y=-450;

% Obtenemos la matriz frontera y se dibuja sobre la figura
[Matriz_pared_manual, XY_ROV] = ObtenerMatrizParedCircular(Desp_X, Desp_Y, distancias_angulares, radio);

% Variables de los límites del entorno (frontera poligonal)
% cerrado=1;
% 
% largo=3;
% ancho=2;
% 
% Corner1_X=-largo/2;
% Corner1_Y=ancho/2;
% 
% Corner2_X=largo/2;
% Corner2_Y=ancho/2;
% 
% Corner3_X=largo/2;
% Corner3_Y=-ancho/2;
% 
% Corner4_X=-largo/2;
% Corner4_Y=-ancho/2;
% 
% % CERRADO
% Corners_X=1000*[Corner1_X Corner2_X Corner3_X Corner4_X Corner1_X];
% Corners_Y=1000*[Corner1_Y Corner2_Y Corner3_Y Corner4_Y Corner1_Y];
% 
% Desp_X=0;
% Desp_Y=0;
% theta=-55;
% theta=theta*pi/180;
%
%[Matriz_pared_manual, XY_corners_T] = ObtenerMatrizParedPoligono(Corners_X,Corners_Y,Desp_X, Desp_Y, cerrado, theta, Posiciones_x, Posiciones_y, distancias_angulares)


%% Variables del filtro
lim_inf_intensidad=80; % por debajo de este valor se considera agua (primera mitad de la muestra)
umbral_conectividad=150; % minimo nº pixeles para ser componente
conn=4; % conectividad vertical-horizontal (4) o en asterisco (8)
distancia_ruido=600; % distancia del ruido que rodea al sonar (mm)
lim_cant_datos=10000; % a partir de este límite se considera ruido y se elimina
lim_min_cant_pez=150; % cantidad mínima de píxeles para ser considerado


%% Bucle de modificación y transmisión del mensaje, representación de datos y estimación de cantidad de peces.
Cerrar=0;
tstart=tic;

while Cerrar==0 
    vuelta=vuelta+1;
    for HeadAngle=0:399
        
        % Modificación del mensaje
        mensaje2601(12)=fix(HeadAngle/256);
        mensaje2601(11)=HeadAngle-256*mensaje2601(12);
        
        checksum=sum_parcial+mensaje2601(11)+mensaje2601(12);
        mensaje2601(24)=fix(checksum/256);
        mensaje2601(23)=checksum-256*mensaje2601(24);
        
        % Transmisión del mensaje
        write(u, mensaje2601, "uint8", "192.168.2.2", 9092); 
        Time=toc(tstart);
        
        % Espera a que estén todos los datos disponibles
        while u.NumBytesAvailable~=1224
            espera=toc(tstart)-Time;
            if espera > 2
                aux=1;
                if u.NumBytesAvailable>0
                    a=read(u,u.NumBytesAvailable, 'uint8');
                end
                disp("Mensaje erróneo");
                write(u, mensaje2601, "uint8", "192.168.2.2", 9092); 
                Time=toc(tstart);
            end
        end
        
        % Recepción y almacenamiento de los datos 'raw'
        Mensaje=read(u,1224,"uint8");
        Matriz_Datos_raw=[Matriz_Datos_raw;[Time HeadAngle Mensaje]];
         
        [m,~]=size(Matriz_Datos_raw);
        
        if vuelta==1
            % Cada 50 muestras, realizamos la identificación y procesado y marcamos el centroide de cada componente
            if HeadAngle==49 || HeadAngle==99 || HeadAngle==149 || HeadAngle==199 || HeadAngle==249 || HeadAngle==299 || HeadAngle==349 ||HeadAngle==399
                prueba(HeadAngle+1)=scatter(x,y,50,zeros(1,1200),'.');
                
                Matriz_datos_360_intensidades=Matriz_Datos_raw(1:HeadAngle, 25:1224);
                [N_peces,ID_peces,centroids_r,datos_360_filtrados]=IdentificacionYFiltro(HeadAngle,Matriz_datos_360_intensidades,Matriz_pared_manual,conn,umbral_conectividad,distancia_ruido,lim_cant_datos,lim_inf_intensidad,lim_min_cant_pez,distancia_puntos,Paso_motor_rad,vuelta);
                
                A=exist('Centroide_peces');
                if A==1
                    delete(Centroide_peces)
                    clear Centroide_peces
                end
                
                Peces.String=num2str(N_peces,'%u');
                for k=1:N_peces
                    x_cent = distancia_puntos*centroids_r(ID_peces(k,1),1).*sin(centroids_r(ID_peces(k,1),2).*Paso_motor_rad);
                    y_cent = distancia_puntos*centroids_r(ID_peces(k,1),1).*cos(centroids_r(ID_peces(k,1),2).*Paso_motor_rad);

                    Centroide_peces(k)=scatter(x_cent,y_cent,50,'k','s','filled');
                    drawnow
                end
                
            else % En el resto de muestras, representamos los datos en crudo
                [datos_raw]=Representacion_PV_TR(Matriz_Datos_raw,m);
                prueba(HeadAngle+1)=scatter(x,y,50,datos_raw,'.');
            end
            
        else % Tras la primera vuelta, se modifican las intensidades de cada punto de acuerdo a los datos nuevos
            if HeadAngle==49 || HeadAngle==99 || HeadAngle==149 || HeadAngle==199 || HeadAngle==249 || HeadAngle==299 || HeadAngle==349 ||HeadAngle==399
                prueba(HeadAngle+1).CData=zeros(1,1200);
                
                % Estructuro las últimas 400 muestras de forma correcta
                Matriz_datos_360_intensidades=[Matriz_datos_360_filtrados(end-HeadAngle+1:end,:);Matriz_datos_360_filtrados(400*(vuelta-2)+HeadAngle+1:400*(vuelta-1),:)]-Matriz_pared_manual;
                [N_peces,ID_peces,centroids_r,datos_360_filtrados]=IdentificacionYFiltro(HeadAngle,Matriz_datos_360_intensidades,Matriz_pared_manual,conn,umbral_conectividad,distancia_ruido,lim_cant_datos,lim_inf_intensidad,lim_min_cant_pez,distancia_puntos,Paso_motor_rad,vuelta);
                
                A=exist('Centroide_peces');
                if A==1
                    delete(Centroide_peces)
                    clear Centroide_peces
                end
                
                Peces.String=num2str(N_peces,'%u');
                for k=1:N_peces
                    x_cent = distancia_puntos*centroids_r(ID_peces(k,1),1).*sin(centroids_r(ID_peces(k,1),2).*Paso_motor_rad);
                    y_cent = distancia_puntos*centroids_r(ID_peces(k,1),1).*cos(centroids_r(ID_peces(k,1),2).*Paso_motor_rad);

                    Centroide_peces(k)=scatter(x_cent,y_cent,50,'k','s','filled');
                    drawnow
                end
            else
                % Se van actualizando los datos
                if HeadAngle>395
                    prueba(HeadAngle-395).CData = zeros(1,1200)+120;
                else
                    prueba(HeadAngle+5).CData = zeros(1,1200)+120;
                end
                [datos_raw]=Representacion_PV_TR(Matriz_Datos_raw,m);
                prueba(HeadAngle+1).CData=datos_raw;
            end
        end
        
        % Almacenamiento de los datos filtrados
        Matriz_datos_360_filtrados=[Matriz_datos_360_filtrados; datos_360_filtrados];
        
        % Acciones a realizar si se pulsan los botones
        Cerrar=Cerrar_Grafico_v2(figura);
        if Cerrar==1
            flush(u,"output");
            close all;
            clear all;
            clc;
            return;
        end
                
        if cambiaGain==1
            [mensaje2601, sum_parcial]=CrearMensajeSonar360_TR(duration, sample_period, freq, n_samples, ganancia, transmit);
            cambiaGain=0;
            disp("Ganancia cambiada");
            pause(0.25);
        elseif cambiaDist==1
            time_to_return=distance/SoundSpeedWater*2;
            time_interval=time_to_return/n_samples; %en us       time_interval=25ns*sample_period
            sample_period=round(time_interval/0.025);
            
            [mensaje2601, sum_parcial]=CrearMensajeSonar360_TR(duration, sample_period, freq, n_samples, ganancia, transmit);
            cambiaDist=0;
            disp("Distancia cambiada");
            pause(0.25)
        end
    end
end

save 'Datos.mat' Matriz_Datos_raw Matriz_datos_360_filtrados

