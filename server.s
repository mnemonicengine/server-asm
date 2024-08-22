.intel_syntax noprefix
.globl _start

.section .text

_start:
    mov rax, 41                 # specify socket syscall
    mov rdi, 2                  # set domain = 2 AF_INET
    mov rsi, 1                  # set type = 1 = SOCK_STREAM
    mov rdx, 0                  # set protocol = 0 (default, here IPPROTO_IP)
    syscall

    mov rbx, rax                # move the socket FD into rbx -> rdi
    mov rdi, rbx

    mov rax, 49                 # specify bind syscall 
    mov rsi, offset sockaddr    # move location of sockaddr into rsi
    mov rdx, 16                 # length of struct sockaddr above = 16
    syscall

    mov rax, 50                 # specify listen syscall. rdi is already set to sockfd
    mov rsi, 0                  # set backlog = 0
    syscall

intake:
    mov rax, 43                 # specify accept syscall. rdi is already set to sockfd
    mov rdi, rbx                # reset rdi to our socket fd for our loop
    mov rsi, 0                  # null
    mov rdx, 0                  # null
    syscall
    mov r14, rax                # move the fd returned from accept (4) into r14

    mov rax, 57                 # specify fork syscall
    syscall
    cmp rax, 0                  # if we are in the parent, jump to parent label
    jne parent

    mov rax, 3                  # if not in parent, specify close syscall
    mov rdi, rbx                # close socket (at fd=3)
    syscall

    mov rax, 0                  # specify read syscall. rdi is already set to sockfd = 4
    mov rdi, r14
    mov rsi, offset request_buf      # *buf
    mov rdx, 1024               # count = size of *buf (number of bytes offset)
    syscall
    mov r10, rax                # move # of bytes read from rax to r10
    

    mov r9, 0                                   # initialize counter to 0
    mov r10, offset filepath                    # initialize r10 to filepath buffer location

    cmp byte ptr [rsi], 'P'
    je post_switch
    mov r13, 0
    jmp request_loop
    post_switch:
    mov r13, 1
    jmp request_loop

request_loop:
    cmp byte ptr [rsi], ' '
    je filepath_loop                            # if we've found first space, enter filepath loop      
    inc rsi
    jmp request_loop                            # else move to next character

filepath_loop:
    inc rsi                                     # move to next character
    mov r8, rsi
    cmp byte ptr [rsi], ' '
    je get_or_post                              # if we've found second space, exit loop
    mov r12b, byte ptr [rsi] 
    mov [r10], r12b                             # write character pointed to by rsi to filepath buffer
    inc r10                                     # increment filepath buffer memory location
    inc r9                                      # increment counter
    jmp filepath_loop

get_or_post:
    cmp r13, 1
    jne handle_get

handle_post:
    mov rax, 2                                  # specify open syscall  
    mov rdi, offset filepath
    mov rsi, 65
    mov rdx, 0777
    syscall                                     # open file in filepath, return its fd (5)
    mov r13, rax                                # set r13 to filepath fd for future use

    mov rsi, offset request_buf
    mov rdi, separator
    mov rdx, 4

    find_separator:                          
        xor r12, r12
        mov r12d, dword ptr [rsi]                    # move next 4 characters from request into r12d
        cmp r12d, dword ptr [separator]
        je found_separator
        inc rsi
        jmp find_separator

    found_separator:
        add rsi, 4                                  # move past the \r\n\r\n
        mov r8, offset file_contents
        xor rcx, rcx                                # zero out rcx for our copy_loop counter

    copy_loop:
        mov al, [rsi]
        cmp al, 0
        je fully_parsed
        mov [r8], al
        inc r8
        inc rsi
        inc rcx
        jmp copy_loop

    fully_parsed:
        mov rax, 1                                  # specify write syscall
        mov rdi, r13                                
        mov rsi, offset file_contents
        mov rdx, rcx
        syscall

        mov rax, 3                                  # specify close syscall
        syscall

        mov rax, 1                                  # specify write syscall
        mov rdi, r14
        mov rsi, offset http_ok
        mov rdx, 19
        syscall

        jmp finish_child

handle_get:
    mov rax, 2                                  # specify open syscall
    mov rdi, offset filepath
    mov rsi, 0
    mov rdx, 0777
    syscall                                     # open file in filepath, return its fd (5)
    mov r13, rax                                # set r13 to filepath fd = 5 for future use

    mov rax, 0                                  # specify read syscall
    mov rdi, r13                                # set fd = r13 = 5
    mov rsi, offset file_contents
    mov rdx, 1024
    syscall
    mov r15, rax                                # move # of bytes returned to r15 for later use

    mov rax, 3                                  # specify close syscall
    syscall    

    mov rax, 1                  # specify write syscall
    mov rdi, r14
    mov rsi, offset http_ok
    mov rdx, 19
    syscall

    mov rax, 1                                  # specify write syscall
    mov rdi, r14
    mov rsi, offset file_contents
    mov rdx, r15
    syscall

    jmp finish_child
    


parent:
    mov rax, 3                  # specify close syscall
    mov rdi, r14                # close the accept() fd
    syscall

    jmp intake                  # return to where we accept() to accept once again in parent

finish_child:
    mov rax, 60                 # specify exit syscall
    mov rdi, 0
    syscall                     # exit



.section .data

#---------------- SOCKADDR ----------------#

sockaddr:
	.2byte 2
	.2byte 0x5000               # big endian!
	.4byte 0x00000000
	.8byte 0

#---------------- BUFFERS -----------------#

request_buf: .skip 1024
filepath: .skip 1024
file_contents: .skip 1024

#--------------- CONSTANTS ----------------#

http_ok: .string "HTTP/1.0 200 OK\r\n\r\n"
sample: .string "testestest"
separator: .ascii "\r\n\r\n"
content_len_str: .skip 1024

#------------------------------------------#
