.global altmalloc
.global altcalloc
.global altrealloc
.global altfree

.data
head:
    .zero 8
.text

/* Pseudocode:
    void *altmalloc(size_t s) {
        block_t *curr = head;
        block_t *min = NULL;
        block_t *last = NULL;
        while (curr != NULL) {
            if (curr->free == 1 && curr->size >= s) {
                if (min == NULL || curr->size < min->size) {
                    min = curr;
                }
            }
            if (curr->next == NULL) {
                last = curr;
            }
            curr = curr->next;
        }

        if (min == NULL) {
            block_t * p;
            p = (block_t*) sbrk(s + BLOCK_SIZE);
            if (p == (void *) -1) {
                return NULL;
            }
            if (last != NULL) {
                last->next = p;
            } else {
                head = p;
            }
            p->size = s + BLOCK_SIZE; p->next = NULL; p->free = 0;
            return p + BLOCK_SIZE;
        } else {
            min->free = 0;
            return min + BLOCK_SIZE;
        }
    }
*/
#  Variable Mappings:
# s is %rdi
# s is %r12
# curr is %r13
# min is %r14
# last is %r15
# p is %rax

altmalloc:
    # Prologue:
    push %r12
    push %r13
    push %r14
    push %r15
    enter $0, $0

    # Body:
    mov %rdi, %r12
    mov head, %r13
    mov $0, %r14
    mov $0, %r15
start_while:
    cmp $0, %r13 # while condition
    je end_while # exit loop
    # while body:
    cmp $1, 16(%r13)
    jne end_if1
    cmp %r12, (%r13)
    jl end_if1
    cmp $0, %r14
    je if_body1
    movq (%r14), %rcx
    cmp %rcx, (%r13)
    jge end_if1
if_body1:
    mov %r13, %r14
end_if1:
    cmp $0, 8(%r13)
    jne end_if2
    mov %r13, %r15
end_if2:
    mov 8(%r13), %r13
    jmp start_while
end_while:
    cmp $0, %r14
    jne else
    add $24, %rdi
    call sbrk
    cmp $-1, %rax
    jne continued
    mov $0, %rax
    jmp end_malloc

continued:
    cmp $0, %r15
    je inner_else
    mov %rax, 8(%r15)
    jmp end_if3
inner_else:
    mov %rax, head
end_if3:
    mov %r12, (%rax)
    add $24, (%rax)
    movq $0, 8(%rax)
    movq $0, 16(%rax)
    add $24, %rax
    jmp end_malloc
else:
    movq $0, 16(%r14)
    mov $24, %rax
    add %r14, %rax
    jmp end_malloc

end_malloc:
    leave 
    # Epilogue:
    pop %r15
    pop %r14
    pop %r13
    pop %r12
    ret

/* Pseudocode:
    void *altcalloc(size_t nmemb, size_t s) {
        char *p;
        p = altmalloc(nmemb * s);

        if (p == -1) {
            return NULL;
        }

        for (size_t i = 0; i < nmemb * s; ++i) {
            p[i] = 0;
        }
        
        return p;
    }
*/
#  Variable Mappings:
# nmemb is %rdi
# s is %rsi
# nmemb * s is %r12
# p is %rax
# i is %rdi

altcalloc:
    # Prologue:
    push %r12
    enter $8, $0

    # Body:
    mov %rdi, %r12
    imul %rsi, %r12
    mov %r12, %rdi
    call altmalloc
    cmp $-1, %rax
    jne end_if4
    mov $0, %rax
    jmp end_calloc
end_if4:
    mov $0, %rdi
start_for1:
    cmp %r12, %rdi
    jge end_calloc
    movb $0, (%rax, %rdi, 1) # movb to move just one byte
    jmp start_for1
end_calloc:
    leave
    # Epilogue:
    pop %r12
    ret

/* Pseudocode:
    void *altrealloc(void *ptr, size_t s) {
        block_t *p = ptr - BLOCK_SIZE;
        if (p->size <= s) {
            return ptr;
        }

        char *new_ptr = altmalloc(s); #FUNCTION CALL!!!!!!
        for (int i = 0; i < p->size; i++) {
            new_ptr[i] = (((char *) p) + BLOCK_SIZE)[i];
        }
        return new_ptr;
    }
*/
#  Variable Mappings:
# ptr is %rdi
# s is %rsi
# p is %r12
# new_ptr is %rax
# i is %rdi

altrealloc:
    # Prologue
    push %r12
    enter $8, $0
    
    # Body:
    mov %rdi, %r12
    sub $24, %r12
    cmp (%rsi), %r12
    jg end_if5
    mov %rdi, %rax
    jmp end_realloc
end_if5:
    mov %rsi, %rdi
    call altmalloc
    mov $0, %rdi
start_for2:
    cmp (%r12), %rdi
    jge end_realloc
    mov (%rdi, %r12, 1), %rsi
    mov %rsi, (%rdi, %rax, 1)
    jmp start_for2

end_realloc:
    leave
    # Epilogue
    pop %r12
    ret

/* Pseudocode:
    void altfree(void *ptr) {
        ((block_t *) (ptr - BLOCK_SIZE))->free = 1;
    }
*/
#  Variable Mappings:
# ptr is %rdi
# ptr - BLOCK_SIZE is %rdi

altfree:
    # Prologue:
    enter $0, $0

    # Body:
    sub $24, %rdi
    movq $1, 16(%rdi)

    leave
    # Epilogue:
    ret
