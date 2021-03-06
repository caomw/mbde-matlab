classdef mbeMechModelPendulumBase < mbeMechModelBase
    % Mechanism physical model: Planar pendulum with one link.
    % Derived classes define particular examples of mechanisms with
    % especific masses, lengths, etc.
    % Modeled in Natural coordinates plus one relative angle coordinate.
    %
    %   (xa,ya)
    %     o 
    %     |
    %     |
    %     |
    %     |
    %     + 1 (q1,q2)
    %
    %  - q3: Angle (xa,ya)-(q1,q2)
    %
    
	% -----------------------------------------------------------------------------
	% This file is part of MBDE-MATLAB.  See: https://github.com/MBDS/mbde-matlab
	% 
	%     MBDE-MATLAB is free software: you can redistribute it and/or modify
	%     it under the terms of the GNU General Public License as published by
	%     the Free Software Foundation, either version 3 of the License, or
	%     (at your option) any later version.
	% 
	%     MBDE-MATLAB is distributed in the hope that it will be useful,
	%     but WITHOUT ANY WARRANTY; without even the implied warranty of
	%     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	%     GNU General Public License for more details.
	% 
	%     You should have received a copy of the GNU General Public License
	%     along with MBDE-MATLAB.  If not, see <http://www.gnu.org/licenses/>.
	% -----------------------------------------------------------------------------
	
    % (Abstract) Read-only, constant properties of the model
    properties(Constant,GetAccess=public)
        % Dependent coordinates count
        dep_coords_count = 3;
        
        % A vector with the indices of the independent coordinates in "q":
        indep_idxs = 3;
    end
    % (Abstract) Read-only properties of the model
    properties(GetAccess=public,SetAccess=public)
        % Initial, approximate position (dep coords) vector
        q_init_approx=zeros(mbeMechModelFourBarsBase.dep_coords_count,1);
        
        % Initial velocity for independent coords
        zp_init=[0];
    end
    
    % Model-specific properties:
    properties(Access=public)
        % Global mass matrix
        M;
        
        % Fixed point coords:
        xA,yA, fixed_points;
        
        % Gravity:
        g = -10;
        
        % lengths:
        bar_lengths; 
        
        % Masses:
        mA1;
        
        % Force vector (gravity forces only):
        Qg;
        
        % damping coefficient
        C = 0;
    end
    
    methods 
        % Constructor: must be implemented in derived classes to fill-in
        % all mechanical parameters.
        
    end
    
    % Implementation of Virtual methods from mbeMechModelBase
    methods(Access=public)
        % Computes the vector of constraints $\Phi(q)$
        function val = phi(me,q)
            x1 = q(1) ;y1 = q(2); theta = q(3);
            LA1 = me.bar_lengths(1);
            val = [(me.xA-x1)^2 + (me.yA-y1)^2 - LA1^2;
                    mbe_iff(abs(sin(theta)) < 0.7,... 
                        y1-me.yA-LA1*sin(theta), ...
                        x1-me.xA-LA1*cos(theta) ...
                        ) ...
                    ];
        end % of phi()
        
        % Computes the Jacobian $\Phi_q$
        function phiq = jacob_phi_q(me,q)
            % (From old code in jacob.m)
            % q: coordinates
            % l: bar length vector
            % x: fixed points positions
            x1 = q(1); y1 = q(2); theta = q(3);
            LA1 = me.bar_lengths(1); 
            phiq = [...
                -2*(me.xA-x1), -2*(me.yA-y1),             0;
                    mbe_iff(abs(sin(theta)) < 0.7,... 
                            [0,             1,            -LA1*cos(theta)], ...
                            [1,             0,            LA1*sin(theta)] ...
                        ) ...
                    ];
        end % jacob_phi_q()

        % Computes the Jacobian $\dot{\Phi_q} \dot{q}$
        function phiqpqp = jacob_phiqp_times_qp(me,q,qp)
            %x1 = q(1) ;y1 = q(2);x2 = q(3);y2 = q(4);
            theta = q(3);
            x1p = qp(1) ;y1p = qp(2); thetap = qp(3);
            LA1 = me.bar_lengths(1);

            dotphiq = [...
                      2*x1p,        2*y1p,            0;
                    mbe_iff(abs(sin(theta)) < 0.7,... 
                          [           0,             0, LA1*sin(theta)*thetap ], ...
                          [           0,             0, LA1*cos(theta)*thetap ]  ...
                          ) ...
                       ];
            phiqpqp = dotphiq * qp;
        end % jacob_phiqp_times_qp
        
        % Computes the hypermatrix $\frac{\partial R}{\partial q}$, with Rq(:,:,k) the partial derivative of R(q) wrt q(k)
        function Rq = jacob_Rq(me,q,R)
            error('to do');
        end
       
        % Evaluates the instantaneous forces
        function Q = eval_forces(me,q,qp)
            Q_var = zeros(me.dep_coords_count,1);
            Q_var(3) = -me.C*qp(3);
            Q = me.Qg+Q_var;
        end % eval_forces

        % Evaluates the stiffness & damping matrices of the system:
        function [K, C] = eval_KC(me, q,dq)
            K = zeros(me.dep_coords_count,me.dep_coords_count);
            C = zeros(me.dep_coords_count,me.dep_coords_count);
            C(3,3) = me.C;
        end

        % Returns a copy of "me" after applying the given model errors (of
        % class mbeModelErrorDef)
        function [bad_model] = applyErrors(me, error_def)
            bad_model = me; 
             
            % Init with no error:
            ini_vel_error = 0;
            ini_pos_error = 0;
            grav_error = 0;
            damping_coef_error = 0;

            switch error_def.error_type
                case 0
                    ini_vel_error = 0;
                    ini_pos_error = 0;
                    grav_error = 0;
                    damping_coef_error = 0;
                % 1: Gravity + initial pos error:
                case 1
                    grav_error = 1*error_def.error_scale;
                    ini_pos_error = error_def.error_scale * pi/16;
                % 2: Initial pos error
                case 2
                    ini_pos_error = error_def.error_scale * pi/16;
                % 3: Initial vel error
                case 3
                    ini_vel_error = 10 * error_def.error_scale;
                % 4: damping (C) param (=0)
                case 4 
                    damping_coef_error = -1*me.C * error_def.error_scale;
                % 5: damping (C) param (=10)
                case 5
                    ini_vel_error = 0;
                    ini_pos_error = 0;
                    grav_error = 0;
                    damping_coef_error = 10 * error_def.error_scale;
                otherwise
                    error('Unhandled value!');
            end
            bad_model.g = bad_model.g+grav_error; % gravity error
            bad_model.zp_init = bad_model.zp_init+ini_vel_error; % initial velocity error
            bad_model.q_init_approx(3)=bad_model.q_init_approx(3)+ini_pos_error; %initial position error
            bad_model.C=bad_model.C+damping_coef_error; %initial position error

            % Weight vector 
            % WARNING: This vector MUST be updated here, after modifying the "g"
            % vector!
            bad_model=bad_model.update_Qg();
        end % applyErrors
        
        % See docs in base class
        function [] = plot_model_skeleton(me, q, color_code, do_fit)
            plot([me.fixed_points(1),q(1)], ...
                 [me.fixed_points(2),q(2)] ,color_code);
            if (do_fit)
                axis equal;
                xlim ([me.fixed_points(1)-1.2*me.bar_lengths(1),me.fixed_points(1)+1.2*me.bar_lengths(1)]);
                ylim ([me.fixed_points(2)-1.2*me.bar_lengths(1),me.fixed_points(2)+1.2*me.bar_lengths(1)]);
            end
        end
        
    end % methods
end % class
