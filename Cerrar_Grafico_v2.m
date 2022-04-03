function Cerrar=Cerrar_Grafico_v2(figura)
global exit_program
global restart
global stop
global play

Cerrar=0;
if exit_program==true
    Cerrar=1;
    %return; 
elseif restart==true
    close(figura);
    IdentificacionPeces();
elseif stop==true
    while play==false
        if exit_program==true
            Cerrar=1;
            %return;               
        elseif restart==true
            close(figura);
            IdentificacionPeces();
        end
        pause(0.1);
    end
    stop=false;
end
play=false;
end